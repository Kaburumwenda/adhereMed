import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../repository/ward_repository.dart';

class AdmissionFormScreen extends ConsumerStatefulWidget {
  final String? admissionId;
  const AdmissionFormScreen({super.key, this.admissionId});

  @override
  ConsumerState<AdmissionFormScreen> createState() => _AdmissionFormScreenState();
}

class _AdmissionFormScreenState extends ConsumerState<AdmissionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = WardRepository();

  final _patientIdCtrl = TextEditingController();
  final _bedIdCtrl = TextEditingController();
  final _doctorIdCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _dischargeSummaryCtrl = TextEditingController();
  DateTime? _admissionDate;
  DateTime? _dischargeDate;
  String _status = 'active';
  bool _loading = false;
  bool _initialLoading = false;

  bool get _isEditing => widget.admissionId != null;

  @override
  void initState() {
    super.initState();
    _admissionDate = DateTime.now();
    if (_isEditing) _loadAdmission();
  }

  @override
  void dispose() {
    _patientIdCtrl.dispose();
    _bedIdCtrl.dispose();
    _doctorIdCtrl.dispose();
    _reasonCtrl.dispose();
    _dischargeSummaryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAdmission() async {
    setState(() => _initialLoading = true);
    try {
      final a = await _repo.getAdmission(int.parse(widget.admissionId!));
      _patientIdCtrl.text = '${a.patientId ?? ''}';
      _bedIdCtrl.text = '${a.bedId ?? ''}';
      _doctorIdCtrl.text = '${a.admittingDoctorId ?? ''}';
      _reasonCtrl.text = a.reason;
      _dischargeSummaryCtrl.text = a.dischargeSummary ?? '';
      _status = a.status;
      _admissionDate = DateTime.tryParse(a.admissionDate);
      if (a.dischargeDate != null) _dischargeDate = DateTime.tryParse(a.dischargeDate!);
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
        'bed': int.tryParse(_bedIdCtrl.text),
        'admitting_doctor': int.tryParse(_doctorIdCtrl.text),
        'reason': _reasonCtrl.text,
        'discharge_summary': _dischargeSummaryCtrl.text,
        'status': _status,
        'admission_date': _admissionDate?.toIso8601String(),
        if (_dischargeDate != null)
          'discharge_date': _dischargeDate!.toIso8601String(),
      };
      if (_isEditing) {
        await _repo.updateAdmission(int.parse(widget.admissionId!), data);
      } else {
        await _repo.createAdmission(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEditing ? 'Admission updated' : 'Patient admitted')));
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
                Text(_isEditing ? 'Edit Admission' : 'New Admission',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
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
                        child: TextFormField(
                          controller: _bedIdCtrl,
                          decoration: const InputDecoration(labelText: 'Bed ID'),
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: TextFormField(
                          controller: _doctorIdCtrl,
                          decoration: const InputDecoration(labelText: 'Doctor ID'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(value: 'active', child: Text('Active')),
                            DropdownMenuItem(value: 'discharged', child: Text('Discharged')),
                            DropdownMenuItem(value: 'transferred', child: Text('Transferred')),
                          ],
                          onChanged: (v) => setState(() => _status = v ?? 'active'),
                        ),
                      ),
                      SizedBox(
                        width: 250,
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _admissionDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setState(() => _admissionDate = d);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Admission Date'),
                            child: Text(
                              _admissionDate != null
                                  ? '${_admissionDate!.year}-${_admissionDate!.month.toString().padLeft(2, '0')}-${_admissionDate!.day.toString().padLeft(2, '0')}'
                                  : 'Select date',
                              style: TextStyle(
                                color: _admissionDate != null
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: TextFormField(
                          controller: _reasonCtrl,
                          decoration: const InputDecoration(labelText: 'Reason for Admission'),
                          maxLines: 3,
                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                      if (_isEditing)
                        SizedBox(
                          width: double.infinity,
                          child: TextFormField(
                            controller: _dischargeSummaryCtrl,
                            decoration: const InputDecoration(labelText: 'Discharge Summary'),
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
                      : Text(_isEditing ? 'Update' : 'Admit Patient'),
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
