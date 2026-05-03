import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/loading_widget.dart';
import '../repository/radiology_repository.dart';

class RadiologyOrderFormScreen extends ConsumerStatefulWidget {
  final String? orderId;
  const RadiologyOrderFormScreen({super.key, this.orderId});

  @override
  ConsumerState<RadiologyOrderFormScreen> createState() =>
      _RadiologyOrderFormScreenState();
}

class _RadiologyOrderFormScreenState
    extends ConsumerState<RadiologyOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = RadiologyRepository();

  final _patientIdCtrl = TextEditingController();
  final _bodyPartCtrl = TextEditingController();
  final _indicationCtrl = TextEditingController();
  String _imagingType = 'xray';
  String _priority = 'routine';
  String _status = 'pending';
  bool _loading = false;
  bool _initialLoading = false;

  bool get _isEditing => widget.orderId != null;

  static const _imagingTypes = [
    ('xray', 'X-Ray'),
    ('ct', 'CT Scan'),
    ('mri', 'MRI'),
    ('ultrasound', 'Ultrasound'),
    ('mammogram', 'Mammogram'),
    ('fluoroscopy', 'Fluoroscopy'),
    ('other', 'Other'),
  ];

  static const _priorities = [
    ('routine', 'Routine'),
    ('urgent', 'Urgent'),
    ('stat', 'Stat'),
  ];

  static const _statuses = [
    ('pending', 'Pending'),
    ('in_progress', 'In Progress'),
    ('completed', 'Completed'),
    ('cancelled', 'Cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadOrder();
  }

  @override
  void dispose() {
    _patientIdCtrl.dispose();
    _bodyPartCtrl.dispose();
    _indicationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    setState(() => _initialLoading = true);
    try {
      final o = await _repo.getOrder(int.parse(widget.orderId!));
      _patientIdCtrl.text = '${o.patientId ?? ''}';
      _imagingType = o.imagingType;
      _bodyPartCtrl.text = o.bodyPart;
      _indicationCtrl.text = o.clinicalIndication ?? '';
      _priority = o.priority;
      _status = o.status;
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
    try {
      final data = {
        'patient': int.tryParse(_patientIdCtrl.text),
        'imaging_type': _imagingType,
        'body_part': _bodyPartCtrl.text,
        'clinical_indication': _indicationCtrl.text,
        'priority': _priority,
        'status': _status,
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
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                const SizedBox(width: 8),
                Text(_isEditing ? 'Edit Radiology Order' : 'New Radiology Order',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 24),
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
                          initialValue: _imagingType,
                          decoration: const InputDecoration(labelText: 'Imaging Type'),
                          items: _imagingTypes
                              .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                              .toList(),
                          onChanged: (v) => setState(() => _imagingType = v ?? 'xray'),
                        ),
                      ),
                      SizedBox(
                        width: 250,
                        child: TextFormField(
                          controller: _bodyPartCtrl,
                          decoration: const InputDecoration(labelText: 'Body Part'),
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<String>(
                          initialValue: _priority,
                          decoration: const InputDecoration(labelText: 'Priority'),
                          items: _priorities
                              .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                              .toList(),
                          onChanged: (v) => setState(() => _priority = v ?? 'routine'),
                        ),
                      ),
                      if (_isEditing)
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            initialValue: _status,
                            decoration: const InputDecoration(labelText: 'Status'),
                            items: _statuses
                                .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                                .toList(),
                            onChanged: (v) => setState(() => _status = v ?? 'pending'),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: TextFormField(
                          controller: _indicationCtrl,
                          decoration: const InputDecoration(labelText: 'Clinical Indication'),
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
