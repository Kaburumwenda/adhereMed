import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/loading_widget.dart';
import '../repository/appointment_repository.dart';

class AppointmentFormScreen extends ConsumerStatefulWidget {
  final String? appointmentId;

  const AppointmentFormScreen({super.key, this.appointmentId});

  @override
  ConsumerState<AppointmentFormScreen> createState() =>
      _AppointmentFormScreenState();
}

class _AppointmentFormScreenState
    extends ConsumerState<AppointmentFormScreen> {
  final _repo = AppointmentRepository();
  final _formKey = GlobalKey<FormState>();

  final _patientIdCtrl = TextEditingController();
  final _doctorIdCtrl = TextEditingController();
  final _departmentIdCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _date;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _appointmentType = 'scheduled';
  bool _loading = false;
  bool _initialLoading = false;

  bool get _isEditing => widget.appointmentId != null;

  static const _types = ['walk_in', 'scheduled', 'follow_up', 'emergency'];

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _initialLoading = true);
    try {
      final a = await _repo.getDetail(int.parse(widget.appointmentId!));
      _patientIdCtrl.text = a.patientId?.toString() ?? '';
      _doctorIdCtrl.text = a.doctorId?.toString() ?? '';
      _departmentIdCtrl.text = a.departmentId?.toString() ?? '';
      _reasonCtrl.text = a.reason ?? '';
      _notesCtrl.text = a.notes ?? '';
      _appointmentType = a.appointmentType ?? 'scheduled';
      _date = DateTime.tryParse(a.date);
      final startParts = a.startTime.split(':');
      if (startParts.length >= 2) {
        _startTime = TimeOfDay(
            hour: int.parse(startParts[0]), minute: int.parse(startParts[1]));
      }
      if (a.endTime != null) {
        final endParts = a.endTime!.split(':');
        if (endParts.length >= 2) {
          _endTime = TimeOfDay(
              hour: int.parse(endParts[0]), minute: int.parse(endParts[1]));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load appointment: $e')),
        );
      }
    }
    if (mounted) setState(() => _initialLoading = false);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null || _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and start time')),
      );
      return;
    }
    setState(() => _loading = true);

    final data = {
      'patient': int.tryParse(_patientIdCtrl.text.trim()),
      'doctor': int.tryParse(_doctorIdCtrl.text.trim()),
      'department': int.tryParse(_departmentIdCtrl.text.trim()),
      'date': _formatDate(_date!),
      'start_time': _formatTime(_startTime!),
      'end_time': _endTime != null ? _formatTime(_endTime!) : null,
      'appointment_type': _appointmentType,
      'reason': _reasonCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
    };

    try {
      if (_isEditing) {
        await _repo.update(int.parse(widget.appointmentId!), data);
      } else {
        await _repo.create(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Appointment ${_isEditing ? 'updated' : 'booked'} successfully')),
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
    _departmentIdCtrl.dispose();
    _reasonCtrl.dispose();
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
                  _isEditing ? 'Edit Appointment' : 'Book Appointment',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _textField('Patient ID', _patientIdCtrl, required: true),
                    _textField('Doctor ID', _doctorIdCtrl, required: true),
                    _textField('Department ID', _departmentIdCtrl),
                    _datePicker(),
                    _timePicker('Start Time', _startTime, (t) {
                      setState(() => _startTime = t);
                    }),
                    _timePicker('End Time', _endTime, (t) {
                      setState(() => _endTime = t);
                    }),
                    SizedBox(
                      width: 280,
                      child: DropdownButtonFormField<String>(
                        initialValue: _appointmentType,
                        decoration:
                            const InputDecoration(labelText: 'Appointment Type'),
                        items: _types
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t.replaceAll('_', ' ').toUpperCase()),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _appointmentType = v ?? 'scheduled'),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: TextFormField(
                        controller: _reasonCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Reason'),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: TextFormField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Notes'),
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
                label: Text(_isEditing ? 'Update Appointment' : 'Book Appointment'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _textField(String label, TextEditingController ctrl,
      {bool required = false}) {
    return SizedBox(
      width: 280,
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null
            : null,
      ),
    );
  }

  Widget _datePicker() {
    return SizedBox(
      width: 280,
      child: TextFormField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'Date',
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        controller: TextEditingController(
          text: _date != null ? _formatDate(_date!) : '',
        ),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _date ?? DateTime.now(),
            firstDate: DateTime.now().subtract(const Duration(days: 30)),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (picked != null) setState(() => _date = picked);
        },
      ),
    );
  }

  Widget _timePicker(
      String label, TimeOfDay? value, ValueChanged<TimeOfDay> onPicked) {
    return SizedBox(
      width: 280,
      child: TextFormField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.access_time, size: 18),
        ),
        controller: TextEditingController(
          text: value != null ? value.format(context) : '',
        ),
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: value ?? TimeOfDay.now(),
          );
          if (picked != null) onPicked(picked);
        },
      ),
    );
  }
}
