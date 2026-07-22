import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import 'hc_common.dart';

/// Opens the shift create/edit bottom sheet. Returns true if a shift was
/// created/updated (caller should refresh).
void showShiftDialog(
  BuildContext context, {
  List<Map> caregivers = const [],
  List<Map> patients = const [],
  List<Map> allShifts = const [],
  Map? existing,
  Map? preselectedCaregiver,
  String? sheetDate,
  required VoidCallback onChanged,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => ShiftDialog(
      caregivers: caregivers,
      patients: patients,
      allShifts: allShifts,
      existing: existing,
      preselectedCaregiver: preselectedCaregiver,
      sheetDate: sheetDate,
      onChanged: onChanged,
    ),
  );
}

const _singleVisitPresets = [
  ('Day 8AM–8PM', Icons.wb_sunny_rounded, '08:00', '20:00', false),
  ('Night 8PM–8AM', Icons.nights_stay_rounded, '20:00', '08:00', true),
  ('Morning 6AM–2PM', Icons.coffee_rounded, '06:00', '14:00', false),
  ('Evening 2PM–10PM', Icons.wb_twilight_rounded, '14:00', '22:00', false),
];

const _liveInPresets = [1, 3, 7, 14, 30];

const _onCallDurations = [15, 30, 60, 120, 240, 480, 720, 1440];

const _multiVisitPresets = [
  ('Morning 8–12', '08:00', '12:00'),
  ('Lunch 12–14', '12:00', '14:00'),
  ('Afternoon 14–18', '14:00', '18:00'),
  ('Evening 18–22', '18:00', '22:00'),
  ('Bedtime 21–22', '21:00', '22:00'),
];

const _kDaysOfWeek = [
  (1, 'Mon'), (2, 'Tue'), (3, 'Wed'), (4, 'Thu'),
  (5, 'Fri'), (6, 'Sat'), (0, 'Sun'),
];

class ShiftDialog extends ConsumerStatefulWidget {
  final List<Map> caregivers;
  final List<Map> patients;
  final List<Map> allShifts;
  final Map? existing;
  final Map? preselectedCaregiver;
  final String? sheetDate;
  final VoidCallback onChanged;
  const ShiftDialog({
    super.key,
    required this.caregivers,
    required this.patients,
    required this.allShifts,
    this.existing,
    this.preselectedCaregiver,
    this.sheetDate,
    required this.onChanged,
  });

  @override
  ConsumerState<ShiftDialog> createState() => _ShiftDialogState();
}

class _ShiftDialogState extends ConsumerState<ShiftDialog> {
  bool get _editing => widget.existing != null;
  bool _saving = false;

  // Form state
  int? _caregiverId;
  int? _patientId;
  String _shiftType = 'visit';
  String _status = 'scheduled';
  String _startDate = '';
  String _startTime = '08:00';
  String _endDate = '';
  String _endTime = '20:00';
  String _rangeStart = '';
  String _rangeEnd = '';
  List<int> _daysOfWeek = [1, 2, 3, 4, 5];
  bool _sameTimeEveryDay = true;
  Map<int, List<({String start, String end})>> _perDayTimes = {};
  String _onCallMode = 'once';
  int _onCallDuration = 60;
  Map<int, int> _onCallPerDayDurations = {};
  final _notes = TextEditingController();
  String _error = '';

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _loadExisting(widget.existing!);
    } else {
      _initNew();
    }
  }

  void _initNew() {
    final today = widget.sheetDate ?? hcDateOffset(0);
    _startDate = today;
    _endDate = today;
    _rangeStart = today;
    final r = DateTime.tryParse('${today}T00:00');
    if (r != null) _rangeEnd = hcYMD(r.add(const Duration(days: 6)));
    if (widget.preselectedCaregiver != null) {
      _caregiverId = widget.preselectedCaregiver!['id'] as int;
      _onCaregiverChange();
    }
  }

  void _loadExisting(Map s) {
    final st = hcSplitDateTime(s['start_at']);
    final en = hcSplitDateTime(s['end_at']);
    _caregiverId = s['caregiver'] as int?;
    _patientId = s['patient'] as int?;
    _shiftType = s['shift_type']?.toString() ?? 'visit';
    _status = s['status']?.toString() ?? 'scheduled';
    _startDate = st.date;
    _startTime = st.time;
    _endDate = en.date;
    _endTime = en.time;
    _notes.text = s['notes']?.toString() ?? '';
    if (_shiftType == 'on_call') {
      _onCallMode = 'once';
      final dur = DateTime.tryParse(s['end_at']?.toString() ?? '')
              ?.difference(DateTime.tryParse(s['start_at']?.toString() ?? '') ?? DateTime.now())
              .inMinutes ??
          60;
      _onCallDuration = dur < 15 ? 15 : dur;
    }
  }

  void _onCaregiverChange() {
    final locked = _liveInLockedPatientId;
    if (locked != null) _patientId = locked;
  }

  int? get _liveInLockedPatientId {
    if (_caregiverId == null) return null;
    final now = DateTime.now();
    for (final s in widget.allShifts) {
      if (s['caregiver'] != _caregiverId) continue;
      if (s['shift_type'] != 'live_in') continue;
      if (widget.existing?['id'] == s['id']) continue;
      final st = DateTime.tryParse(s['start_at']?.toString() ?? '');
      final en = DateTime.tryParse(s['end_at']?.toString() ?? '');
      if (st == null || en == null) continue;
      if (now.isAfter(st) && now.isBefore(en)) return s['patient'] as int;
    }
    return null;
  }

  String? get _patientLockedLabel {
    final pid = _liveInLockedPatientId;
    if (pid == null) return null;
    for (final s in widget.allShifts) {
      if (s['caregiver'] == _caregiverId && s['shift_type'] == 'live_in' && s['patient'] == pid) {
        return 'Patient (locked: ${s['patient_name'] ?? '—'})';
      }
    }
    return null;
  }

  DateTime? _toIso(String date, String time) {
    final dt = DateTime.tryParse('$date\T$time');
    return dt;
  }

  String hcYMD(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _shiftDuration() {
    final s = _toIso(_startDate, _startTime);
    final e = _toIso(_endDate, _endTime);
    if (s == null || e == null) return '';
    final diff = e.difference(s).inMinutes;
    if (diff <= 0) return '';
    final h = diff ~/ 60, m = diff % 60;
    if (h >= 24) {
      final d = h ~/ 24, rh = h % 24;
      return '${d}d ${rh}h';
    }
    return '${h}h${m > 0 ? ' ${m}m' : ''}';
  }

  String? _conflictMessage() {
    if (_caregiverId == null) return null;
    if (_shiftType == 'multi_visit') return null;
    if (_shiftType == 'on_call' && _onCallMode == 'recurring' && !_editing) return null;
    final s = _toIso(_startDate, _startTime);
    DateTime? e;
    if (_shiftType == 'on_call' && _onCallMode == 'once' && !_editing) {
      e = s?.add(Duration(minutes: _onCallDuration));
    } else {
      e = _toIso(_endDate, _endTime);
    }
    if (s == null || e == null || !e.isAfter(s)) return null;
    for (final x in widget.allShifts) {
      if (x['caregiver'] != _caregiverId) continue;
      if (widget.existing?['id'] == x['id']) continue;
      final xs = DateTime.tryParse(x['start_at']?.toString() ?? '');
      final xe = DateTime.tryParse(x['end_at']?.toString() ?? '');
      if (xs == null || xe == null) continue;
      if (x['status'] == 'cancelled' || x['status'] == 'missed') continue;
      if (xs.isBefore(e) && xe.isAfter(s)) {
        return 'Overlaps existing shift with ${x['patient_name']} '
            '(${hcTime(x['start_at'])} – ${hcTime(x['end_at'])}, ${hcShiftTypeLabel(x['shift_type']?.toString())}).';
      }
    }
    return null;
  }

  List<({String startAt, String endAt})> _expandMultiVisit() {
    final out = <({String startAt, String endAt})>[];
    final days = _iterDateRange(_rangeStart, _rangeEnd);
    for (final d in days) {
      if (!_daysOfWeek.contains(d.weekday % 7)) continue;
      final dayStr = hcYMD(d);
      final list = _sameTimeEveryDay
          ? [(_startTime, _endTime)]
          : (_perDayTimes[d.weekday % 7] ?? []).map((s) => (s.start, s.end)).toList();
      for (final (start, end) in list) {
        final s = _toIso(dayStr, start);
        var e = _toIso(dayStr, end);
        if (s != null && e != null && !e.isAfter(s)) {
          e = _toIso(hcYMD(d.add(const Duration(days: 1))), end);
        }
        if (s != null && e != null) {
          out.add((startAt: s.toUtc().toIso8601String(), endAt: e.toUtc().toIso8601String()));
        }
      }
    }
    return out;
  }

  List<({String startAt, String endAt})> _expandOnCallRecurring() {
    final out = <({String startAt, String endAt})>[];
    final days = _iterDateRange(_rangeStart, _rangeEnd);
    for (final d in days) {
      if (!_daysOfWeek.contains(d.weekday % 7)) continue;
      final dayStr = hcYMD(d);
      final minutes = _sameTimeEveryDay
          ? _onCallDuration
          : (_onCallPerDayDurations[d.weekday % 7] ?? _onCallDuration);
      final startTime = _sameTimeEveryDay
          ? _startTime
          : (_perDayTimes[d.weekday % 7]?.firstOrNull?.start ?? _startTime);
      final s = _toIso(dayStr, startTime);
      if (s == null) continue;
      final e = s.add(Duration(minutes: minutes));
      out.add((startAt: s.toUtc().toIso8601String(), endAt: e.toUtc().toIso8601String()));
    }
    return out;
  }

  List<DateTime> _iterDateRange(String? startStr, String? endStr) {
    final out = <DateTime>[];
    if (startStr == null || endStr == null) return out;
    final start = DateTime.tryParse('${startStr}T00:00');
    final end = DateTime.tryParse('${endStr}T00:00');
    if (start == null || end == null) return out;
    for (DateTime d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      out.add(d);
    }
    return out;
  }

  int get _expandedCount {
    if (_editing) return 0;
    if (_shiftType == 'multi_visit') return _expandMultiVisit().length;
    if (_shiftType == 'on_call' && _onCallMode == 'recurring') return _expandOnCallRecurring().length;
    return 0;
  }

  List<Map<String, dynamic>> _buildPayloads() {
    final base = <String, dynamic>{
      'caregiver': _caregiverId,
      'patient': _patientId,
      'notes': _notes.text.trim(),
    };
    if (_editing) {
      final s = _toIso(_startDate, _startTime);
      final e = _toIso(_endDate, _endTime);
      return [
        {
          ...base,
          'shift_type': _shiftType == 'multi_visit' ? 'visit' : _shiftType,
          'start_at': s!.toUtc().toIso8601String(),
          'end_at': e!.toUtc().toIso8601String(),
          'status': _status,
        }
      ];
    }
    if (_shiftType == 'visit') {
      final s = _toIso(_startDate, _startTime);
      final e = _toIso(_endDate, _endTime);
      return [
        {...base, 'shift_type': 'visit', 'start_at': s!.toUtc().toIso8601String(), 'end_at': e!.toUtc().toIso8601String()}
      ];
    }
    if (_shiftType == 'live_in') {
      final s = _toIso(_startDate, _startTime);
      final e = _toIso(_endDate, _endTime);
      return [
        {...base, 'shift_type': 'live_in', 'start_at': s!.toUtc().toIso8601String(), 'end_at': e!.toUtc().toIso8601String()}
      ];
    }
    if (_shiftType == 'multi_visit') {
      return _expandMultiVisit()
          .map((s) => {...base, 'shift_type': 'visit', 'start_at': s.startAt, 'end_at': s.endAt})
          .toList();
    }
    if (_shiftType == 'on_call') {
      if (_onCallMode == 'once') {
        final s = _toIso(_startDate, _startTime);
        final e = s!.add(Duration(minutes: _onCallDuration));
        return [
          {...base, 'shift_type': 'on_call', 'start_at': s.toUtc().toIso8601String(), 'end_at': e.toUtc().toIso8601String()}
        ];
      }
      return _expandOnCallRecurring()
          .map((s) => {...base, 'shift_type': 'on_call', 'start_at': s.startAt, 'end_at': s.endAt})
          .toList();
    }
    return [];
  }

  Future<void> _save() async {
    setState(() => _error = '');
    if (_caregiverId == null) {
      setState(() => _error = 'Caregiver is required.');
      return;
    }
    if (_patientId == null) {
      setState(() => _error = 'Patient is required.');
      return;
    }
    final isRecurring = !_editing &&
        (_shiftType == 'multi_visit' ||
            (_shiftType == 'on_call' && _onCallMode == 'recurring'));
    if (isRecurring) {
      if (_rangeStart.isEmpty || _rangeEnd.isEmpty) {
        setState(() => _error = 'Pick a date range.');
        return;
      }
      if (DateTime.tryParse('$_rangeEnd\T00:00')!.isBefore(DateTime.tryParse('$_rangeStart\T00:00')!)) {
        setState(() => _error = 'End date is before start date.');
        return;
      }
      if (_daysOfWeek.isEmpty) {
        setState(() => _error = 'Pick at least one day of the week.');
        return;
      }
    } else {
      final s = _toIso(_startDate, _startTime);
      if (s == null) {
        setState(() => _error = 'Invalid start.');
        return;
      }
      DateTime? e;
      if (_shiftType == 'on_call' && _onCallMode == 'once' && !_editing) {
        e = s.add(Duration(minutes: _onCallDuration));
      } else {
        e = _toIso(_endDate, _endTime);
      }
      if (e == null || !e.isAfter(s)) {
        setState(() => _error = 'End must be after start.');
        return;
      }
    }

    final payloads = _buildPayloads();
    if (payloads.isEmpty) {
      setState(() => _error = 'Nothing to schedule.');
      return;
    }

    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      if (_editing) {
        await dio.patch('/homecare/schedules/${widget.existing!['id']}/', data: payloads[0]);
        if (mounted) Navigator.pop(context, true);
        _snack('Shift updated');
      } else {
        var ok = 0, fail = 0;
        for (final p in payloads) {
          try {
            await dio.post('/homecare/schedules/', data: p);
            ok++;
          } catch (_) {
            fail++;
          }
        }
        if (mounted) Navigator.pop(context, true);
        if (fail == 0) {
          _snack('Created $ok shift${ok == 1 ? '' : 's'}');
        } else {
          _snack('Created $ok of ${payloads.length} — $fail failed');
        }
      }
      widget.onChanged();
    } catch (e) {
      String msg = 'Failed to save shift';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map) {
          if (data['detail'] != null) {
            msg = data['detail'].toString();
          } else {
            final first = data.entries.first;
            msg = '${first.key}: ${first.value is List ? (first.value as List).first : first.value}';
          }
        }
      } catch (_) {}
      if (mounted) setState(() { _error = msg; _saving = false; });
    }
  }

  Future<void> _delete() async {
    if (widget.existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete shift?'),
        content: Text('Delete shift with ${widget.existing!['patient_name']}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: hcRed),
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/homecare/schedules/${widget.existing!['id']}/');
      if (mounted) {
        Navigator.pop(context, true);
        _snack('Shift deleted');
        widget.onChanged();
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to delete');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _applySingleVisitPreset(String start, String end, bool overnight) {
    _startTime = start;
    _endTime = end;
    if (_startDate.isEmpty) _startDate = hcDateOffset(0);
    final startD = DateTime.tryParse('$_startDate\T$start');
    var endD = DateTime.tryParse('$_startDate\T$end');
    if (overnight || endD == null || !endD.isAfter(startD!)) {
      endD = startD!.add(const Duration(days: 1));
      final parts = end.split(':');
      endD = DateTime(endD.year, endD.month, endD.day, int.parse(parts[0]), int.parse(parts[1]));
    }
    _endDate = hcYMD(endD);
    setState(() {});
  }

  void _applyLiveInPreset(int days) {
    if (_startDate.isEmpty) _startDate = hcDateOffset(0);
    _startTime = _startTime.isEmpty ? '08:00' : _startTime;
    _endTime = _startTime;
    final startD = DateTime.tryParse('$_startDate\T$_startTime');
    if (startD != null) {
      _endDate = hcYMD(startD.add(Duration(days: days)));
    }
    setState(() {});
  }

  void _applyOnCallDuration(int minutes) {
    _onCallDuration = minutes;
    if (_onCallMode == 'once') {
      if (_startDate.isEmpty) _startDate = hcDateOffset(0);
      if (_startTime.isEmpty) _startTime = '09:00';
      final startD = _toIso(_startDate, _startTime);
      if (startD != null) {
        final endD = startD.add(Duration(minutes: minutes));
        _endDate = hcYMD(endD);
        _endTime = '${endD.hour.toString().padLeft(2, '0')}:${endD.minute.toString().padLeft(2, '0')}';
      }
    }
    setState(() {});
  }

  void _toggleDay(int value) {
    setState(() {
      if (_daysOfWeek.contains(value)) {
        _daysOfWeek.remove(value);
      } else {
        _daysOfWeek.add(value);
        _daysOfWeek.sort();
      }
    });
  }

  Future<void> _pickDate(String label, String Function() getter, void Function(String) setter) async {
    final initial = DateTime.tryParse('${getter()}T00:00') ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: initial,
    );
    if (d != null) {
      setter(hcYMD(d));
      setState(() {});
    }
  }

  Future<void> _pickTime(String label, String Function() getter, void Function(String) setter) async {
    final parts = getter().split(':');
    final initial = TimeOfDay(hour: int.tryParse(parts.first) ?? 8, minute: int.tryParse(parts.last) ?? 0);
    final t = await showTimePicker(context: context, initialTime: initial);
    if (t != null) {
      setter('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lockedLabel = _patientLockedLabel;
    final availablePatients = lockedLabel != null
        ? widget.patients.where((p) => p['id'] == _liveInLockedPatientId).toList()
        : widget.patients;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: hcPurple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(_editing ? Icons.edit_calendar_rounded : Icons.add_circle_rounded, color: hcPurple, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(_editing ? 'Edit shift' : 'New shift assignment',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, size: 20)),
            ]),
            const Divider(height: 16),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // Caregiver dropdown
                  DropdownButtonFormField<int>(
                    initialValue: _caregiverId,
                    decoration: const InputDecoration(labelText: 'Caregiver *', prefixIcon: Icon(Icons.favorite_rounded)),
                    items: widget.caregivers.map((c) => DropdownMenuItem<int>(
                      value: c['id'] as int,
                      child: Text('${c['user']?['full_name'] ?? c['user']?['email'] ?? 'Caregiver'} · ${hcCategoryLabel(c['category']?.toString())}',
                          overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() { _caregiverId = v; _onCaregiverChange(); }),
                  ),
                  const SizedBox(height: 10),
                  // Patient dropdown
                  DropdownButtonFormField<int>(
                    initialValue: _patientId,
                    decoration: InputDecoration(
                      labelText: lockedLabel ?? 'Patient *',
                      prefixIcon: const Icon(Icons.person_rounded),
                      hintText: lockedLabel != null
                          ? 'Caregiver is on live-in — locked to this patient.'
                          : null,
                    ),
                    items: availablePatients.map((p) => DropdownMenuItem<int>(
                      value: p['id'] as int,
                      child: Text('${p['user']?['full_name'] ?? 'Patient'} · ${p['medical_record_number'] ?? ''}',
                          overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: lockedLabel != null ? null : (v) => setState(() => _patientId = v),
                  ),
                  const SizedBox(height: 14),
                  // Shift type picker
                  Text('SHIFT TYPE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final t in const [
                      ('visit', 'Single visit', Icons.directions_walk_rounded),
                      ('multi_visit', 'Multiple visits', Icons.calendar_view_week_rounded),
                      ('on_call', 'On call', Icons.phone_in_talk_rounded),
                      ('live_in', 'Live-in', Icons.home_rounded),
                    ])
                      FilledButton.tonal(
                        onPressed: _editing && t.$1 == 'multi_visit' ? null : () => setState(() => _shiftType = t.$1),
                        style: FilledButton.styleFrom(
                          backgroundColor: _shiftType == t.$1 ? hcPurple.withValues(alpha: 0.15) : null,
                          foregroundColor: _shiftType == t.$1 ? hcPurple : cs.onSurfaceVariant,
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(t.$3, size: 16), const SizedBox(width: 6), Text(t.$2)]),
                      ),
                  ]),
                  if (_editing) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.flag_rounded)),
                      items: const [
                        DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                        DropdownMenuItem(value: 'checked_in', child: Text('Checked in')),
                        DropdownMenuItem(value: 'completed', child: Text('Completed')),
                        DropdownMenuItem(value: 'missed', child: Text('Missed')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? 'scheduled'),
                    ),
                  ],
                  const SizedBox(height: 14),
                  ..._buildShiftTypeFields(),
                  // Preview chips
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    if (_shiftDuration().isNotEmpty && _shiftType != 'multi_visit')
                      Chip(
                        avatar: Icon(Icons.hourglass_top_rounded, size: 14, color: hcIndigo),
                        label: Text('Duration ${_shiftDuration()}', style: TextStyle(fontSize: 12, color: hcIndigo)),
                        backgroundColor: hcIndigo.withValues(alpha: 0.08),
                        side: BorderSide.none, padding: EdgeInsets.zero,
                      ),
                    if (_expandedCount > 0)
                      Chip(
                        avatar: Icon(Icons.calendar_month_rounded, size: 14, color: hcPurple),
                        label: Text('Will create $_expandedCount shift(s)', style: TextStyle(fontSize: 12, color: hcPurple)),
                        backgroundColor: hcPurple.withValues(alpha: 0.08),
                        side: BorderSide.none, padding: EdgeInsets.zero,
                      ),
                    if (_shiftType == 'live_in')
                      Chip(
                        avatar: Icon(Icons.home_rounded, size: 14, color: hcPurple),
                        label: Text('Live-in · caregiver reserved', style: TextStyle(fontSize: 12, color: hcPurple)),
                        backgroundColor: hcPurple.withValues(alpha: 0.08),
                        side: BorderSide.none, padding: EdgeInsets.zero,
                      ),
                  ]),
                  if (_conflictMessage() != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: hcAmber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Icon(Icons.warning_rounded, size: 16, color: hcAmber),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_conflictMessage()!, style: TextStyle(fontSize: 12, color: hcAmber))),
                      ]),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notes,
                    decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.note_rounded)),
                    maxLines: 2,
                  ),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(_error, style: TextStyle(color: cs.error, fontSize: 12.5)),
                    ),
                  const SizedBox(height: 16),
                  Row(children: [
                    if (_editing)
                      TextButton.icon(
                        onPressed: _saving ? null : _delete,
                        icon: Icon(Icons.delete_rounded, color: hcRed, size: 18),
                        label: Text('Delete', style: TextStyle(color: hcRed)),
                      ),
                    const Spacer(),
                    TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(backgroundColor: hcPurple),
                      icon: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(_editing ? Icons.save_rounded : Icons.add_rounded, size: 18),
                      label: Text(_editing ? 'Save changes' : 'Create shift'),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildShiftTypeFields() {
    final cs = Theme.of(context).colorScheme;
    switch (_shiftType) {
      case 'visit':
        return [
          Text('QUICK PRESETS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in _singleVisitPresets)
              ActionChip(
                avatar: Icon(p.$2, size: 14, color: hcAmber),
                label: Text(p.$1, style: const TextStyle(fontSize: 12)),
                onPressed: () => _applySingleVisitPreset(p.$3, p.$4, p.$5),
              ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _dateField('Start date', _startDate, (v) => _startDate = v)),
            const SizedBox(width: 10),
            Expanded(child: _timeField('Start time', _startTime, (v) => _startTime = v)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _dateField('End date', _endDate, (v) => _endDate = v)),
            const SizedBox(width: 10),
            Expanded(child: _timeField('End time', _endTime, (v) => _endTime = v)),
          ]),
        ];
      case 'live_in':
        return [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: hcBlue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(Icons.info_rounded, size: 16, color: hcBlue),
              const SizedBox(width: 8),
              Expanded(child: Text('Live-in: caregiver is reserved exclusively for this patient for the entire stay.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
            ]),
          ),
          const SizedBox(height: 10),
          Text('DURATION PRESETS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final days in _liveInPresets)
              ActionChip(label: Text('$days day${days == 1 ? '' : 's'}', style: const TextStyle(fontSize: 12)), onPressed: () => _applyLiveInPreset(days)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _dateField('Start date', _startDate, (v) => _startDate = v)),
            const SizedBox(width: 10),
            Expanded(child: _timeField('Start time', _startTime, (v) => _startTime = v)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _dateField('End date', _endDate, (v) => _endDate = v)),
            const SizedBox(width: 10),
            Expanded(child: _timeField('End time', _endTime, (v) => _endTime = v)),
          ]),
        ];
      case 'on_call':
        return [
          if (!_editing) ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'once', label: Text('Once'), icon: Icon(Icons.looks_one_rounded, size: 18)),
                ButtonSegment(value: 'recurring', label: Text('Recurring'), icon: Icon(Icons.calendar_view_week_rounded, size: 18)),
              ],
              selected: {_onCallMode},
              onSelectionChanged: (s) => setState(() => _onCallMode = s.first),
            ),
            const SizedBox(height: 10),
          ],
          Text('DURATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in _onCallDurations)
              ChoiceChip(
                label: Text(m < 60 ? '${m}min' : m == 60 ? '1hr' : '${m ~/ 60}hrs', style: const TextStyle(fontSize: 12)),
                selected: _onCallDuration == m,
                onSelected: (_) => _applyOnCallDuration(m),
              ),
          ]),
          const SizedBox(height: 10),
          if (_editing || _onCallMode == 'once') ...[
            Row(children: [
              Expanded(child: _dateField('Date', _startDate, (v) => _startDate = v)),
              const SizedBox(width: 10),
              Expanded(child: _timeField('Start time', _startTime, (v) => _startTime = v)),
            ]),
            if (_editing) ...[
              const SizedBox(height: 10),
              _timeField('End time', _endTime, (v) => _endTime = v),
            ],
          ] else ...[
            Row(children: [
              Expanded(child: _dateField('Range start', _rangeStart, (v) => _rangeStart = v)),
              const SizedBox(width: 10),
              Expanded(child: _dateField('Range end', _rangeEnd, (v) => _rangeEnd = v)),
            ]),
            const SizedBox(height: 10),
            _daysOfWeekSelector(),
            const SizedBox(height: 10),
            SwitchListTile(
              value: _sameTimeEveryDay,
              onChanged: (v) => setState(() => _sameTimeEveryDay = v),
              title: const Text('Same start time and duration every day', style: TextStyle(fontSize: 13)),
              dense: true, contentPadding: EdgeInsets.zero,
            ),
            if (_sameTimeEveryDay)
              _timeField('Start time', _startTime, (v) => _startTime = v)
            else
              ..._buildPerDayOnCall(),
          ],
        ];
      case 'multi_visit':
        return [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: hcBlue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(Icons.info_rounded, size: 16, color: hcBlue),
              const SizedBox(width: 8),
              Expanded(child: Text('Schedule visits across multiple days of the week within a date range.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _dateField('Range start', _rangeStart, (v) => _rangeStart = v)),
            const SizedBox(width: 10),
            Expanded(child: _dateField('Range end', _rangeEnd, (v) => _rangeEnd = v)),
          ]),
          const SizedBox(height: 10),
          _daysOfWeekSelector(),
          const SizedBox(height: 10),
          SwitchListTile(
            value: _sameTimeEveryDay,
            onChanged: (v) => setState(() => _sameTimeEveryDay = v),
            title: const Text('Same time on every selected day', style: TextStyle(fontSize: 13)),
            dense: true, contentPadding: EdgeInsets.zero,
          ),
          if (_sameTimeEveryDay) ...[
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final p in _multiVisitPresets)
                ActionChip(
                  label: Text(p.$1, style: const TextStyle(fontSize: 12)),
                  onPressed: () => setState(() { _startTime = p.$2; _endTime = p.$3; }),
                ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _timeField('Start time', _startTime, (v) => _startTime = v)),
              const SizedBox(width: 10),
              Expanded(child: _timeField('End time', _endTime, (v) => _endTime = v)),
            ]),
          ] else
            ..._buildPerDayMultiVisit(),
        ];
      default:
        return [];
    }
  }

  Widget _daysOfWeekSelector() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('DAYS OF WEEK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const Spacer(),
        TextButton(onPressed: () => setState(() => _daysOfWeek = [1, 2, 3, 4, 5]), child: const Text('Weekdays', style: TextStyle(fontSize: 12))),
        TextButton(onPressed: () => setState(() => _daysOfWeek = [0, 1, 2, 3, 4, 5, 6]), child: const Text('All', style: TextStyle(fontSize: 12))),
      ]),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final d in _kDaysOfWeek)
          FilterChip(
            label: Text(d.$2, style: const TextStyle(fontSize: 12)),
            selected: _daysOfWeek.contains(d.$1),
            onSelected: (_) => _toggleDay(d.$1),
          ),
      ]),
    ]);
  }

  List<Widget> _buildPerDayOnCall() {
    return [
      for (final d in _kDaysOfWeek)
        if (_daysOfWeek.contains(d.$1))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(width: 54, child: Chip(label: Text(d.$2, style: const TextStyle(fontSize: 11)))),
              const SizedBox(width: 8),
              Expanded(child: _timeField('Start', _perDayTimes[d.$1]?.firstOrNull?.start ?? _startTime, (v) {
                setState(() {
                  _perDayTimes[d.$1] = [(start: v, end: '')];
                });
              })),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _onCallPerDayDurations[d.$1] ?? _onCallDuration,
                  decoration: const InputDecoration(labelText: 'Duration', isDense: true),
                  items: _onCallDurations.map((m) => DropdownMenuItem(value: m, child: Text(m < 60 ? '${m}min' : m == 60 ? '1hr' : '${m ~/ 60}hrs'))).toList(),
                  onChanged: (v) => setState(() => _onCallPerDayDurations[d.$1] = v ?? _onCallDuration),
                ),
              ),
            ]),
          ),
    ];
  }

  List<Widget> _buildPerDayMultiVisit() {
    return [
      for (final d in _kDaysOfWeek)
        if (_daysOfWeek.contains(d.$1))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: hcPurple.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: hcPurple.withValues(alpha: 0.15))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Chip(label: Text(d.$2, style: const TextStyle(fontSize: 11))),
                const SizedBox(width: 8),
                Text('${(_perDayTimes[d.$1] ?? []).length} slot(s)', style: const TextStyle(fontSize: 11)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  onPressed: () => _showAddSlotMenu(d.$1),
                ),
              ]),
              for (int i = 0; i < (_perDayTimes[d.$1] ?? []).length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Expanded(child: _timeField('Start', _perDayTimes[d.$1]![i].start, (v) {
                      setState(() {
                        final list = List<({String start, String end})>.from(_perDayTimes[d.$1]!);
                        list[i] = (start: v, end: list[i].end);
                        _perDayTimes[d.$1] = list;
                      });
                    })),
                    const SizedBox(width: 8),
                    Expanded(child: _timeField('End', _perDayTimes[d.$1]![i].end, (v) {
                      setState(() {
                        final list = List<({String start, String end})>.from(_perDayTimes[d.$1]!);
                        list[i] = (start: list[i].start, end: v);
                        _perDayTimes[d.$1] = list;
                      });
                    })),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 16, color: hcRed),
                      onPressed: () => setState(() {
                        final list = List<({String start, String end})>.from(_perDayTimes[d.$1]!);
                        list.removeAt(i);
                        _perDayTimes[d.$1] = list;
                      }),
                    ),
                  ]),
                ),
            ]),
          ),
    ];
  }

  void _showAddSlotMenu(int dayValue) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.all(16), child: Text('Add slot', style: TextStyle(fontWeight: FontWeight.w800))),
        for (final p in _multiVisitPresets)
          ListTile(
            leading: Icon(Icons.add_rounded, size: 18),
            title: Text(p.$1),
            onTap: () {
              setState(() {
                _perDayTimes[dayValue] = [...?_perDayTimes[dayValue], (start: p.$2, end: p.$3)];
              });
              Navigator.pop(context);
            },
          ),
        ListTile(
          leading: Icon(Icons.edit_rounded, size: 18),
          title: const Text('Custom slot'),
          onTap: () {
            setState(() {
              _perDayTimes[dayValue] = [...?_perDayTimes[dayValue], (start: '09:00', end: '10:00')];
            });
            Navigator.pop(context);
          },
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _dateField(String label, String value, void Function(String) onChanged) {
    return OutlinedButton.icon(
      onPressed: () => _pickDate(label, () => value, onChanged),
      icon: const Icon(Icons.calendar_today_rounded, size: 16),
      label: Text(value.isEmpty ? label : '$label: $value', style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _timeField(String label, String value, void Function(String) onChanged) {
    return OutlinedButton.icon(
      onPressed: () => _pickTime(label, () => value, onChanged),
      icon: const Icon(Icons.access_time_rounded, size: 16),
      label: Text(value.isEmpty ? label : '$label: $value', style: const TextStyle(fontSize: 12)),
    );
  }
}
