import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/prescription_model.dart';
import '../repository/prescription_repository.dart';

/// Searches the global medications catalog.
Future<List<Map<String, dynamic>>> _searchMedications(String query) async {
  if (query.length < 2) return [];
  try {
    final response = await ApiClient.instance
        .get('/medications/search/', queryParameters: {'q': query});
    final data = response.data;
    // Handle both paginated ({"results": [...]}) and plain list responses
    final List results =
        data is List ? data : (data['results'] as List?) ?? [];
    return results.cast<Map<String, dynamic>>();
  } catch (e) {
    debugPrint('Medication search error: $e');
    return [];
  }
}

class PrescriptionFormScreen extends ConsumerStatefulWidget {
  final String? prescriptionId;
  const PrescriptionFormScreen({super.key, this.prescriptionId});

  @override
  ConsumerState<PrescriptionFormScreen> createState() =>
      _PrescriptionFormScreenState();
}

class _ItemControllers {
  final TextEditingController medicationName;
  final TextEditingController dosage;
  final TextEditingController frequency;
  final TextEditingController duration;
  final TextEditingController quantity;
  final TextEditingController instructions;

  _ItemControllers({
    String name = '',
    String dos = '',
    String freq = '',
    String dur = '',
    String qty = '1',
    String inst = '',
  })  : medicationName = TextEditingController(text: name),
        dosage = TextEditingController(text: dos),
        frequency = TextEditingController(text: freq),
        duration = TextEditingController(text: dur),
        quantity = TextEditingController(text: qty),
        instructions = TextEditingController(text: inst);

  factory _ItemControllers.fromItem(PrescriptionItem item) {
    return _ItemControllers(
      name: item.medicationName,
      dos: item.dosage,
      freq: item.frequency,
      dur: item.duration,
      qty: item.quantity.toString(),
      inst: item.instructions ?? '',
    );
  }

  void dispose() {
    medicationName.dispose();
    dosage.dispose();
    frequency.dispose();
    duration.dispose();
    quantity.dispose();
    instructions.dispose();
  }
}

class _PrescriptionFormScreenState
    extends ConsumerState<PrescriptionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = PrescriptionRepository();

  final _patientSearchCtrl = TextEditingController();
  int? _selectedPatientId;
  String? _selectedPatientName;
  List<Map<String, dynamic>> _patientResults = [];
  bool _searchingPatients = false;
  Timer? _debounce;

  final _notesCtrl = TextEditingController();
  String _status = 'active';

  final List<_ItemControllers> _items = [];

  bool _loading = false;
  bool _initialLoading = false;

  bool get _isEditing => widget.prescriptionId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadPrescription();
    } else {
      _items.add(_ItemControllers());
    }
  }

  @override
  void dispose() {
    _patientSearchCtrl.dispose();
    _notesCtrl.dispose();
    _debounce?.cancel();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPrescription() async {
    setState(() => _initialLoading = true);
    try {
      final p = await _repo.getDetail(int.parse(widget.prescriptionId!));
      _selectedPatientId = p.patientId;
      _selectedPatientName = p.patientName ?? 'Patient #${p.patientId}';
      _patientSearchCtrl.text = _selectedPatientName!;
      _notesCtrl.text = p.notes ?? '';
      _status = p.status;
      for (final item in p.items) {
        _items.add(_ItemControllers.fromItem(item));
      }
      if (_items.isEmpty) _items.add(_ItemControllers());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _initialLoading = false);
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
    } catch (e) {
      debugPrint('Patient search error: $e');
    }
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

  void _addItem() {
    _items.add(_ItemControllers());
    setState(() {});
  }

  void _removeItem(int index) {
    _items[index].dispose();
    _items.removeAt(index);
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final data = {
        'patient': _selectedPatientId,
        'status': _status,
        'notes': _notesCtrl.text,
        'items': _items
            .map((i) => {
                  'medication_name': i.medicationName.text,
                  'dosage': i.dosage.text,
                  'frequency': i.frequency.text,
                  'duration': i.duration.text,
                  'quantity': int.tryParse(i.quantity.text) ?? 1,
                  'instructions': i.instructions.text,
                })
            .toList(),
      };
      if (_isEditing) {
        await _repo.update(int.parse(widget.prescriptionId!), data);
      } else {
        await _repo.create(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                _isEditing ? 'Prescription updated' : 'Prescription created')));
        context.go('/prescriptions');
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      String message = 'Failed to save prescription.';
      if (data is Map) {
        final errors = data.entries
            .map((e) =>
                e.value is List ? (e.value as List).join(', ') : '${e.value}')
            .join('\n');
        if (errors.isNotEmpty) message = errors;
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isEditing ? 'Edit Prescription' : 'Write Prescription',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient selection card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Patient',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
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
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)))
                                : _selectedPatientId != null
                                    ? Icon(Icons.check_circle,
                                        color: AppColors.success)
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
                                    backgroundColor:
                                        AppColors.primary.withValues(alpha: 0.1),
                                    child: Text(
                                      ((p['name'] as String?) ?? '?')
                                          .characters
                                          .first
                                          .toUpperCase(),
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12),
                                    ),
                                  ),
                                  title: Text(p['name'] as String? ?? ''),
                                  subtitle: Text(
                                    'ID: ${p['id']} • ${p['patient_number']}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                  ),
                                  onTap: () => _selectPatient(p),
                                );
                              },
                            ),
                          ),
                        if (_selectedPatientId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Chip(
                              avatar: Icon(Icons.person,
                                  size: 16, color: AppColors.primary),
                              label: Text(
                                  '$_selectedPatientName (ID: $_selectedPatientId)'),
                              onDeleted: () => setState(() {
                                _selectedPatientId = null;
                                _selectedPatientName = null;
                                _patientSearchCtrl.clear();
                              }),
                            ),
                          ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            initialValue: _status,
                            decoration:
                                const InputDecoration(labelText: 'Status'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'active', child: Text('Active')),
                              DropdownMenuItem(
                                  value: 'dispensed',
                                  child: Text('Dispensed')),
                              DropdownMenuItem(
                                  value: 'cancelled',
                                  child: Text('Cancelled')),
                              DropdownMenuItem(
                                  value: 'expired',
                                  child: Text('Expired')),
                            ],
                            onChanged: (v) =>
                                setState(() => _status = v ?? 'active'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Notes'),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Medication items card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Medications',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: _addItem,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Medication'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(_items.length, (i) {
                          final item = _items[i];
                          return Card(
                            color: AppColors.background,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Text('Medication ${i + 1}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      const Spacer(),
                                      if (_items.length > 1)
                                        IconButton(
                                          icon: Icon(Icons.close,
                                              size: 18,
                                              color: AppColors.error),
                                          onPressed: () => _removeItem(i),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      SizedBox(
                                        width: 300,
                                        child: _MedicationAutocomplete(
                                          controller: item.medicationName,
                                          validator: (v) =>
                                              v == null || v.isEmpty
                                                  ? 'Required'
                                                  : null,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 150,
                                        child: TextFormField(
                                          controller: item.dosage,
                                          decoration: const InputDecoration(
                                              labelText: 'Dosage',
                                              isDense: true),
                                          validator: (v) =>
                                              v == null || v.isEmpty
                                                  ? 'Required'
                                                  : null,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 150,
                                        child: TextFormField(
                                          controller: item.frequency,
                                          decoration: const InputDecoration(
                                              labelText: 'Frequency',
                                              isDense: true),
                                          validator: (v) =>
                                              v == null || v.isEmpty
                                                  ? 'Required'
                                                  : null,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 120,
                                        child: TextFormField(
                                          controller: item.duration,
                                          decoration: const InputDecoration(
                                              labelText: 'Duration',
                                              isDense: true),
                                          validator: (v) =>
                                              v == null || v.isEmpty
                                                  ? 'Required'
                                                  : null,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: TextFormField(
                                          controller: item.quantity,
                                          decoration: const InputDecoration(
                                              labelText: 'Qty',
                                              isDense: true),
                                          keyboardType: TextInputType.number,
                                        ),
                                      ),
                                      SizedBox(
                                        width: 300,
                                        child: TextFormField(
                                          controller: item.instructions,
                                          decoration: const InputDecoration(
                                              labelText: 'Instructions',
                                              isDense: true),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
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
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : Text(_isEditing
                              ? 'Update Prescription'
                              : 'Create Prescription'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => context.go('/prescriptions'),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Autocomplete medication field. Searches the global catalog as the user
/// types. If no match is found, the user can keep their custom entry.
class _MedicationAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const _MedicationAutocomplete({
    required this.controller,
    this.validator,
  });

  @override
  State<_MedicationAutocomplete> createState() =>
      _MedicationAutocompleteState();
}

class _MedicationAutocompleteState extends State<_MedicationAutocomplete> {
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _showDropdown = false;
  Timer? _debounce;
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Delay to allow tap on dropdown item
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _removeOverlay();
      });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (value.length < 2) {
        setState(() {
          _results = [];
          _showDropdown = false;
        });
        _removeOverlay();
        return;
      }
      setState(() => _searching = true);
      final results = await _searchMedications(value);
      if (mounted) {
        setState(() {
          _results = results;
          _searching = false;
          _showDropdown = results.isNotEmpty;
        });
        if (_showDropdown) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    });
  }

  void _selectMedication(Map<String, dynamic> med) {
    widget.controller.text = med['generic_name'] as String? ?? '';
    setState(() {
      _showDropdown = false;
      _results = [];
    });
    _removeOverlay();
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 300,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 48),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, index) {
                  final med = _results[index];
                  final label = med['label'] as String? ?? med['generic_name'] ?? '';
                  final category = med['category'] as String? ?? '';
                  return InkWell(
                    onTap: () => _selectMedication(med),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.medication_rounded,
                                size: 14, color: AppColors.primary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                if (category.isNotEmpty)
                                  Text(category,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: 'Medication Name',
          isDense: true,
          prefixIcon: const Icon(Icons.medication_outlined, size: 20),
          suffixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
          helperText: 'Type to search or enter custom name',
          helperStyle: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        onChanged: _onChanged,
        validator: widget.validator,
      ),
    );
  }
}
