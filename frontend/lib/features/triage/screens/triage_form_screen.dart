import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../repository/triage_repository.dart';

class TriageFormScreen extends ConsumerStatefulWidget {
  final String? triageId;

  const TriageFormScreen({super.key, this.triageId});

  @override
  ConsumerState<TriageFormScreen> createState() => _TriageFormScreenState();
}

class _TriageFormScreenState extends ConsumerState<TriageFormScreen> {
  final _repo = TriageRepository();
  final _formKey = GlobalKey<FormState>();

  final _patientIdCtrl = TextEditingController();
  final _temperatureCtrl = TextEditingController();
  final _systolicCtrl = TextEditingController();
  final _diastolicCtrl = TextEditingController();
  final _pulseCtrl = TextEditingController();
  final _respiratoryCtrl = TextEditingController();
  final _o2Ctrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  double _painLevel = 0;
  String _triageCategory = 'standard';
  bool _loading = false;
  bool _initialLoading = false;

  bool get _isEditing => widget.triageId != null;

  static const _categories = ['emergency', 'urgent', 'standard', 'non_urgent'];

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _initialLoading = true);
    try {
      final t = await _repo.getDetail(int.parse(widget.triageId!));
      _patientIdCtrl.text = t.patientId?.toString() ?? '';
      _temperatureCtrl.text = t.temperature?.toString() ?? '';
      _systolicCtrl.text = t.systolicBp?.toString() ?? '';
      _diastolicCtrl.text = t.diastolicBp?.toString() ?? '';
      _pulseCtrl.text = t.pulseRate?.toString() ?? '';
      _respiratoryCtrl.text = t.respiratoryRate?.toString() ?? '';
      _o2Ctrl.text = t.oxygenSaturation?.toString() ?? '';
      _weightCtrl.text = t.weight?.toString() ?? '';
      _heightCtrl.text = t.height?.toString() ?? '';
      _notesCtrl.text = t.notes ?? '';
      _painLevel = (t.painLevel ?? 0).toDouble();
      _triageCategory = t.triageCategory ?? 'standard';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load triage record: $e')),
        );
      }
    }
    if (mounted) setState(() => _initialLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final data = {
      'patient': int.tryParse(_patientIdCtrl.text.trim()),
      'temperature': double.tryParse(_temperatureCtrl.text.trim()),
      'systolic_bp': int.tryParse(_systolicCtrl.text.trim()),
      'diastolic_bp': int.tryParse(_diastolicCtrl.text.trim()),
      'pulse_rate': int.tryParse(_pulseCtrl.text.trim()),
      'respiratory_rate': int.tryParse(_respiratoryCtrl.text.trim()),
      'oxygen_saturation': double.tryParse(_o2Ctrl.text.trim()),
      'weight': double.tryParse(_weightCtrl.text.trim()),
      'height': double.tryParse(_heightCtrl.text.trim()),
      'pain_level': _painLevel.round(),
      'triage_category': _triageCategory,
      'notes': _notesCtrl.text.trim(),
    };

    try {
      if (_isEditing) {
        await _repo.update(int.parse(widget.triageId!), data);
      } else {
        await _repo.create(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Triage record ${_isEditing ? 'updated' : 'saved'} successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _patientIdCtrl.dispose();
    _temperatureCtrl.dispose();
    _systolicCtrl.dispose();
    _diastolicCtrl.dispose();
    _pulseCtrl.dispose();
    _respiratoryCtrl.dispose();
    _o2Ctrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
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
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 8),
                Text(
                  _isEditing ? 'Edit Triage' : 'Record Vitals',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Patient
            _sectionTitle('Patient'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: 280,
                  child: TextFormField(
                    controller: _patientIdCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Patient ID'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Patient ID is required'
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Vital Signs
            _sectionTitle('Vital Signs'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _numField('Temperature (°C)', _temperatureCtrl),
                    _numField('Systolic BP (mmHg)', _systolicCtrl),
                    _numField('Diastolic BP (mmHg)', _diastolicCtrl),
                    _numField('Pulse Rate (bpm)', _pulseCtrl),
                    _numField('Respiratory Rate', _respiratoryCtrl),
                    _numField('O₂ Saturation (%)', _o2Ctrl),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Measurements
            _sectionTitle('Measurements'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _numField('Weight (kg)', _weightCtrl),
                    _numField('Height (cm)', _heightCtrl),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Pain Level
            _sectionTitle('Pain Level'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Pain Level: '),
                        Text(
                          '${_painLevel.round()}/10',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _painLevel > 7
                                ? AppColors.error
                                : _painLevel > 4
                                    ? AppColors.warning
                                    : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _painLevel,
                      min: 0,
                      max: 10,
                      divisions: 10,
                      label: _painLevel.round().toString(),
                      onChanged: (v) => setState(() => _painLevel = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Triage Category
            _sectionTitle('Classification'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    SizedBox(
                      width: 280,
                      child: DropdownButtonFormField<String>(
                        initialValue: _triageCategory,
                        decoration: const InputDecoration(
                            labelText: 'Triage Category'),
                        items: _categories
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c
                                      .replaceAll('_', ' ')
                                      .toUpperCase()),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _triageCategory = v ?? 'standard'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _loading ? null : _save,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(
                    _isEditing ? 'Update Record' : 'Save Vitals'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      );

  Widget _numField(String label, TextEditingController ctrl) {
    return SizedBox(
      width: 200,
      child: TextFormField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
