import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../repository/consultation_repository.dart';

class ConsultationFormScreen extends ConsumerStatefulWidget {
  final String? consultationId;

  const ConsultationFormScreen({super.key, this.consultationId});

  @override
  ConsumerState<ConsultationFormScreen> createState() =>
      _ConsultationFormScreenState();
}

class _ConsultationFormScreenState
    extends ConsumerState<ConsultationFormScreen> {
  final _repo = ConsultationRepository();
  final _formKey = GlobalKey<FormState>();

  final _patientIdCtrl = TextEditingController();
  final _doctorIdCtrl = TextEditingController();
  final _appointmentIdCtrl = TextEditingController();
  final _chiefComplaintCtrl = TextEditingController();
  final _historyCtrl = TextEditingController();
  final _examinationCtrl = TextEditingController();
  final _diagnosisCtrl = TextEditingController();
  final _treatmentPlanCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _status = 'in_progress';
  bool _loading = false;
  bool _initialLoading = false;

  bool get _isEditing => widget.consultationId != null;

  static const _statuses = ['in_progress', 'completed', 'follow_up_needed'];

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _initialLoading = true);
    try {
      final c = await _repo.getDetail(int.parse(widget.consultationId!));
      _patientIdCtrl.text = c.patientId?.toString() ?? '';
      _doctorIdCtrl.text = c.doctorId?.toString() ?? '';
      _appointmentIdCtrl.text = c.appointmentId?.toString() ?? '';
      _chiefComplaintCtrl.text = c.chiefComplaint ?? '';
      _historyCtrl.text = c.historyOfPresentIllness ?? '';
      _examinationCtrl.text = c.examination ?? '';
      _diagnosisCtrl.text = c.diagnosis ?? '';
      _treatmentPlanCtrl.text = c.treatmentPlan ?? '';
      _notesCtrl.text = c.notes ?? '';
      _status = c.status;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load consultation: $e')),
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
      'doctor': int.tryParse(_doctorIdCtrl.text.trim()),
      'appointment': int.tryParse(_appointmentIdCtrl.text.trim()),
      'chief_complaint': _chiefComplaintCtrl.text.trim(),
      'history_of_present_illness': _historyCtrl.text.trim(),
      'examination': _examinationCtrl.text.trim(),
      'diagnosis': _diagnosisCtrl.text.trim(),
      'treatment_plan': _treatmentPlanCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
      'status': _status,
    };

    try {
      if (_isEditing) {
        await _repo.update(int.parse(widget.consultationId!), data);
      } else {
        await _repo.create(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Consultation ${_isEditing ? 'updated' : 'created'} successfully')),
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
    _doctorIdCtrl.dispose();
    _appointmentIdCtrl.dispose();
    _chiefComplaintCtrl.dispose();
    _historyCtrl.dispose();
    _examinationCtrl.dispose();
    _diagnosisCtrl.dispose();
    _treatmentPlanCtrl.dispose();
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
                  _isEditing ? 'Edit Consultation' : 'New Consultation',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // References
            _sectionTitle('References'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _textField('Patient ID', _patientIdCtrl, required: true),
                    _textField('Doctor ID', _doctorIdCtrl, required: true),
                    _textField('Appointment ID', _appointmentIdCtrl),
                    SizedBox(
                      width: 280,
                      child: DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration:
                            const InputDecoration(labelText: 'Status'),
                        items: _statuses
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child:
                                      Text(s.replaceAll('_', ' ').toUpperCase()),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _status = v ?? 'in_progress'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Clinical Notes
            _sectionTitle('Clinical Notes'),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _textArea('Chief Complaint', _chiefComplaintCtrl),
                    const SizedBox(height: 16),
                    _textArea(
                        'History of Present Illness', _historyCtrl),
                    const SizedBox(height: 16),
                    _textArea('Examination', _examinationCtrl),
                    const SizedBox(height: 16),
                    _textArea('Diagnosis', _diagnosisCtrl),
                    const SizedBox(height: 16),
                    _textArea('Treatment Plan', _treatmentPlanCtrl),
                    const SizedBox(height: 16),
                    _textArea('Notes', _notesCtrl),
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
                    _isEditing ? 'Update Consultation' : 'Save Consultation'),
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

  Widget _textField(String label, TextEditingController ctrl,
      {bool required = false}) {
    return SizedBox(
      width: 280,
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) =>
                v == null || v.trim().isEmpty ? '$label is required' : null
            : null,
      ),
    );
  }

  Widget _textArea(String label, TextEditingController ctrl) {
    return TextFormField(
      controller: ctrl,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
      ),
    );
  }
}
