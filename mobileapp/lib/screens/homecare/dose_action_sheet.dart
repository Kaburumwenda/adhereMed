import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../providers/auth_provider.dart';
import 'hc_common.dart';

/// PIN-verified dose action sheet — supports document / skip / not_given / edit.
class DoseActionSheet extends ConsumerStatefulWidget {
  final Map dose;
  final String actionType; // document | skip | not_given | edit
  final VoidCallback onDone;
  const DoseActionSheet(
      {super.key, required this.dose, required this.actionType, required this.onDone});

  @override
  ConsumerState<DoseActionSheet> createState() => _DoseActionSheetState();
}

class _DoseActionSheetState extends ConsumerState<DoseActionSheet> {
  late final String _actionType = widget.actionType;
  late String _actionStatus = widget.actionType == 'edit'
      ? (widget.dose['status'] == 'missed' ? 'taken' : widget.dose['status']?.toString() ?? 'taken')
      : 'taken';
  late final TextEditingController _dose =
      TextEditingController(text: widget.dose['dose']?.toString() ?? '');
  final _pin = TextEditingController();
  final _reason = TextEditingController();
  final _notes = TextEditingController();
  late DateTime _adminTime = DateTime.tryParse(widget.dose['administered_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();
  bool _saving = false;

  bool get _needsReason => _actionType == 'skip' || _actionType == 'not_given' || _actionType == 'edit';

  bool get _showTime => _actionType == 'document' || (_actionType == 'edit' && _actionStatus == 'taken');

  static const _editStatuses = [
    ('pending', 'Pending'),
    ('taken', 'Documented'),
    ('missed', 'Missed'),
    ('skipped', 'Skipped'),
    ('not_given', 'Not given'),
  ];

  Future<void> _pickTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _adminTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_adminTime));
    if (t == null) return;
    setState(() => _adminTime = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _submit() async {
    final pin = _pin.text.trim();
    if (pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your staff PIN.')));
      return;
    }
    final myPin = ref.read(authProvider).user?.pin;
    if (myPin != null && myPin.isNotEmpty && pin != myPin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN does not match.'), backgroundColor: hcRed));
      return;
    }
    if (_needsReason && _reason.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A reason is required.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = <String, dynamic>{
        'pin': pin,
        if (_reason.text.trim().isNotEmpty) 'reason': _reason.text.trim(),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      };
      String verb;
      if (_actionType == 'edit') {
        verb = 'edit_assessment';
        payload['status'] = _actionStatus;
        if (_dose.text.trim().isNotEmpty && _dose.text.trim() != (widget.dose['dose'] ?? '').toString()) {
          payload['dose'] = _dose.text.trim();
        }
        if (_actionStatus == 'taken') payload['administered_at'] = _adminTime.toUtc().toIso8601String();
      } else {
        verb = switch (_actionType) {
          'document' => 'mark_taken',
          'skip' => 'mark_skipped',
          'not_given' => 'mark_not_given',
          _ => 'mark_taken',
        };
        if (_actionType == 'document') payload['administered_at'] = _adminTime.toUtc().toIso8601String();
      }
      await dio.post('/homecare/doses/${widget.dose['id']}/$verb/', data: payload);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dose updated.'), backgroundColor: hcTeal));
        widget.onDone();
      }
    } catch (e) {
      String msg = 'Could not update dose.';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map && data['detail'] != null) msg = data['detail'].toString();
      } catch (_) {}
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: hcRed));
      }
    }
  }

  @override
  void dispose() {
    _pin.dispose();
    _reason.dispose();
    _notes.dispose();
    _dose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_actionType == 'edit' ? 'Edit dose assessment' : 'Document dose',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text('${widget.dose['medication_name']} · ${widget.dose['dose'] ?? ''} · ${widget.dose['patient_name']}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          if (_actionType == 'edit') ...[
            const Text('Change status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final s in _editStatuses)
                  ChoiceChip(
                    label: Text(s.$2),
                    selected: _actionStatus == s.$1,
                    onSelected: (_) => setState(() => _actionStatus = s.$1),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Dose adjustment', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            TextField(
              controller: _dose,
              decoration: const InputDecoration(labelText: 'Custom dose', isDense: true, prefixIcon: Icon(Icons.medication_rounded, size: 18)),
            ),
            const SizedBox(height: 12),
          ],
          if (_showTime) ...[
            Row(children: [
              const Icon(Icons.schedule_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Time given: ${hcDateTime(_adminTime.toIso8601String())}')),
              TextButton(onPressed: _pickTime, child: const Text('Change')),
            ]),
            const SizedBox(height: 12),
          ],
          if (_needsReason)
            TextField(
              controller: _reason,
              decoration: const InputDecoration(labelText: 'Reason (required)', isDense: true),
            ),
          if (_needsReason) const SizedBox(height: 10),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notes (optional)', isDense: true),
          ),
          const SizedBox(height: 12),
          HcPinField(controller: _pin, myPin: auth.user?.pin),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: hcTeal),
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('Save'),
            ),
          ),
        ]),
      ),
    );
  }
}
