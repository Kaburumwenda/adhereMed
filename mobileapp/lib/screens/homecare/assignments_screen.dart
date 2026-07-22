import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api.dart';
import '../../providers/auth_provider.dart';
import 'hc_common.dart';
import 'my_assignments_screen.dart';
import 'visit_check_sheet.dart';
import 'shift_dialog.dart';

/// Role-aware entry: caregivers get an isolated read-only view of their own
/// shifts and assigned patients; admins/managers get the full assignments
/// workspace.
class HomecareAssignmentsEntry extends ConsumerWidget {
  const HomecareAssignmentsEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCaregiver = ref.watch(authProvider).role == 'caregiver';
    return isCaregiver
        ? const HomecareMyAssignmentsScreen()
        : const HomecareAssignmentsScreen();
  }
}

/// Homecare assignment workspace — mirrors the web /homecare/assignments page.
/// Four tabs: Shift sheets, Caregiver calendar, Patient calendar, Patient assignments.
class HomecareAssignmentsScreen extends ConsumerStatefulWidget {
  const HomecareAssignmentsScreen({super.key});

  @override
  ConsumerState<HomecareAssignmentsScreen> createState() =>
      _HomecareAssignmentsScreenState();
}

class _HomecareAssignmentsScreenState
    extends ConsumerState<HomecareAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Data ──
  List<Map> _caregivers = [];
  List<Map> _patients = [];
  List<Map> _shifts = [];
  bool _loadingCg = false;
  bool _loadingShifts = false;

  // ── Tab 1: Sheet filters ──
  String _cgSearch = '';
  String _sheetFilter = 'all';
  String _categoryFilter = 'all';
  String _sheetDate = hcDateOffset(0);

  // ── Tab 2: Caregiver calendar ──
  int? _calCaregiverId;
  String _calRange = 'week';
  String _calAnchor = hcDateOffset(0);
  String _calCustomStart = hcDateOffset(0);
  String _calCustomEnd = hcDateOffset(6);
  static const _calDayCapacityMin = 12 * 60;

  // ── Tab 3: Patient calendar ──
  int? _patCalPatientId;
  String _patCalRange = 'week';
  String _patCalAnchor = hcDateOffset(0);
  String _patCalCustomStart = hcDateOffset(0);
  String _patCalCustomEnd = hcDateOffset(6);
  static const _patDayCapacityMin = 24 * 60;

  // ── Tab 4: Patient assignments ──
  String _cgSearch2 = '';
  String _patientSearch = '';
  String _patientFilter = 'all';
  int? _selectedCaregiverId;
  Set<int> _initialAssigned = {};
  Set<int> _currentAssigned = {};
  bool _loadingAssignments = false;
  bool _saving = false;

  bool get _isCaregiver =>
      ref.read(authProvider).user?.role == 'caregiver';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _tabController.previousIndex) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ═════════════════════════════════════════════════════════
  //  DATA LOADING
  // ═════════════════════════════════════════════════════════

  Future<void> _loadAll() async {
    setState(() => _loadingCg = true);
    try {
      final results = await Future.wait([
        hcFetchAll(ref, '/homecare/caregivers/', params: {'page_size': 500}),
        hcFetchAll(ref, '/homecare/patients/', params: {'page_size': 1000}),
      ]);
      _caregivers = results[0].cast<Map>();
      _patients = results[1].cast<Map>();
    } catch (_) {
      _snack('Failed to load data', hcRed);
    } finally {
      setState(() => _loadingCg = false);
    }
    await _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() => _loadingShifts = true);
    try {
      final baseStart = DateTime.tryParse('$_sheetDate\T00:00')?.add(const Duration(days: -1)) ?? DateTime.now();
      final baseEnd = DateTime.tryParse('$_sheetDate\T00:00')?.add(const Duration(days: 14)) ?? DateTime.now().add(const Duration(days: 14));
      var start = baseStart, end = baseEnd;
      final cs = _calRangeBounds;
      if (cs != null) {
        final cStart = DateTime.tryParse('${cs.start}T00:00');
        final cEnd = DateTime.tryParse('${cs.end}T23:59');
        if (cStart != null && cStart.isBefore(start)) start = cStart;
        if (cEnd != null && cEnd.isAfter(end)) end = cEnd;
      }
      final ps = _patCalRangeBounds;
      if (ps != null) {
        final pStart = DateTime.tryParse('${ps.start}T00:00');
        final pEnd = DateTime.tryParse('${ps.end}T23:59');
        if (pStart != null && pStart.isBefore(start)) start = pStart;
        if (pEnd != null && pEnd.isAfter(end)) end = pEnd;
      }
      final data = await hcFetchAll(ref, '/homecare/schedules/', params: {
        'page_size': 1000,
        'start_after': start.toUtc().toIso8601String(),
        'end_before': end.toUtc().toIso8601String(),
      });
      _shifts = data.cast<Map>();
    } catch (_) {
      _shifts = [];
    } finally {
      if (mounted) setState(() => _loadingShifts = false);
    }
  }

  // ═════════════════════════════════════════════════════════
  //  AVAILABILITY HELPERS
  // ═════════════════════════════════════════════════════════

  Map? _caregiverNowShift(int cgId) {
    final now = DateTime.now();
    for (final s in _shifts) {
      if (s['caregiver'] != cgId) continue;
      if (s['status'] == 'cancelled' || s['status'] == 'missed') continue;
      final st = DateTime.tryParse(s['start_at']?.toString() ?? '');
      final en = DateTime.tryParse(s['end_at']?.toString() ?? '');
      if (st != null && en != null && now.isAfter(st) && now.isBefore(en)) {
        return s;
      }
    }
    return null;
  }

  Map? _caregiverNextShift(int cgId) {
    final now = DateTime.now();
    final candidates = _shifts.where((s) =>
        s['caregiver'] == cgId &&
        s['status'] != 'cancelled' &&
        s['status'] != 'missed').toList();
    candidates.sort((a, b) =>
        DateTime.parse(a['start_at']).compareTo(DateTime.parse(b['start_at'])));
    for (final s in candidates) {
      final st = DateTime.tryParse(s['start_at']?.toString() ?? '');
      if (st != null && st.isAfter(now)) return s;
    }
    return null;
  }

  Map? _caregiverIsLiveIn(int cgId) {
    final cur = _caregiverNowShift(cgId);
    return (cur != null && cur['shift_type'] == 'live_in') ? cur : null;
  }

  String _availabilityLabel(Map c) {
    final cur = _caregiverNowShift(c['id'] as int);
    if (cur != null) {
      if (cur['shift_type'] == 'live_in') return 'Live-in';
      return 'Engaged · until ${hcTime(cur['end_at'])}';
    }
    if (c['is_available'] == false) return 'Off duty';
    return 'Available';
  }

  Color _availabilityColor(Map c) {
    final cur = _caregiverNowShift(c['id'] as int);
    if (cur != null && cur['shift_type'] == 'live_in') return hcPurple;
    if (cur != null) return hcAmber;
    if (c['is_available'] == false) return hcSlate;
    return hcGreen;
  }

  // ═════════════════════════════════════════════════════════
  //  TAB 1: SHIFT SHEETS
  // ═════════════════════════════════════════════════════════

  List<Map> get _filteredSheetCaregivers {
    final q = _cgSearch.trim().toLowerCase();
    return _caregivers.where((c) {
      if (_categoryFilter != 'all' && c['category'] != _categoryFilter) return false;
      if (_sheetFilter == 'available') {
        if (_caregiverNowShift(c['id'] as int) != null || c['is_available'] == false) return false;
      } else if (_sheetFilter == 'engaged') {
        if (_caregiverNowShift(c['id'] as int) == null) return false;
      } else if (_sheetFilter == 'livein') {
        if (_caregiverIsLiveIn(c['id'] as int) == null) return false;
      } else if (_sheetFilter == 'off') {
        if (c['is_available'] != false) return false;
      }
      if (q.isNotEmpty) {
        final blob = '${c['user']?['full_name'] ?? ''} ${c['user']?['email'] ?? ''} ${c['license_number'] ?? ''}'.toLowerCase();
        if (!blob.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  List<Map> _shiftsForCaregiver(int cgId) {
    final out = _shifts.where((s) {
      if (s['caregiver'] != cgId) return false;
      return hcSplitDateTime(s['start_at']).date == _sheetDate;
    }).toList();
    out.sort((a, b) => DateTime.parse(a['start_at']).compareTo(DateTime.parse(b['start_at'])));
    return out;
  }

  // ═════════════════════════════════════════════════════════
  //  TAB 2: CAREGIVER CALENDAR
  // ═════════════════════════════════════════════════════════

  ({String start, String end})? get _calRangeBounds {
    if (_calRange == 'custom') {
      if (_calCustomStart.isEmpty || _calCustomEnd.isEmpty) return null;
      final a = _calCustomStart, b = _calCustomEnd;
      return a.compareTo(b) <= 0 ? (start: a, end: b) : (start: b, end: a);
    }
    final anchor = DateTime.tryParse('${_calAnchor}T00:00');
    if (anchor == null) return null;
    if (_calRange == 'day') return (start: _hcYMD(anchor), end: _hcYMD(anchor));
    if (_calRange == 'week') {
      final dow = (anchor.weekday - 1) % 7;
      final start = anchor.subtract(Duration(days: dow));
      final end = start.add(const Duration(days: 6));
      return (start: _hcYMD(start), end: _hcYMD(end));
    }
    if (_calRange == 'month') {
      final start = DateTime(anchor.year, anchor.month, 1);
      final end = DateTime(anchor.year, anchor.month + 1, 0);
      return (start: _hcYMD(start), end: _hcYMD(end));
    }
    return null;
  }

  List<_CalDay> get _calDays => _buildDays(_calRangeBounds);
  String get _calRangeLabel => _rangeLabel(_calRangeBounds);

  List<Map> get _calCaregiversForDisplay {
    if (_calCaregiverId != null) {
      return _caregivers.where((c) => c['id'] == _calCaregiverId).toList();
    }
    return _caregivers;
  }

  List<_CalRow> get _calRows {
    final days = _calDays;
    if (days.isEmpty) return [];
    return _calCaregiversForDisplay.map((c) {
      final byDay = <String, List<Map>>{};
      final byDayMin = <String, int>{};
      var totalEngagedMin = 0;
      for (final d in days) {
        byDay[d.iso] = [];
        byDayMin[d.iso] = 0;
      }
      for (final s in _shifts) {
        if (s['caregiver'] != c['id'] || s['status'] == 'cancelled') continue;
        final sd = hcSplitDateTime(s['start_at']).date;
        if (!byDay.containsKey(sd)) continue;
        byDay[sd]!.add(s);
        final mins = DateTime.parse(s['end_at']).difference(DateTime.parse(s['start_at'])).inMinutes;
        byDayMin[sd] = (byDayMin[sd] ?? 0) + mins;
        totalEngagedMin += mins;
      }
      final byDayPct = <String, int>{};
      for (final d in days) {
        byDay[d.iso]!.sort((a, b) => DateTime.parse(a['start_at']).compareTo(DateTime.parse(b['start_at'])));
        byDayPct[d.iso] = ((byDayMin[d.iso]! / _calDayCapacityMin) * 100).round().clamp(0, 100);
      }
      final totalCapacityMin = days.length * _calDayCapacityMin;
      final utilization = totalCapacityMin > 0
          ? ((totalEngagedMin / totalCapacityMin) * 100).round().clamp(0, 100)
          : 0;
      return _CalRow(caregiver: c, byDay: byDay, byDayMin: byDayMin, byDayPct: byDayPct, totalEngagedMin: totalEngagedMin, utilization: utilization);
    }).toList();
  }

  // ═════════════════════════════════════════════════════════
  //  TAB 3: PATIENT CALENDAR
  // ═════════════════════════════════════════════════════════

  ({String start, String end})? get _patCalRangeBounds {
    if (_patCalRange == 'custom') {
      if (_patCalCustomStart.isEmpty || _patCalCustomEnd.isEmpty) return null;
      final a = _patCalCustomStart, b = _patCalCustomEnd;
      return a.compareTo(b) <= 0 ? (start: a, end: b) : (start: b, end: a);
    }
    final anchor = DateTime.tryParse('${_patCalAnchor}T00:00');
    if (anchor == null) return null;
    if (_patCalRange == 'day') return (start: _hcYMD(anchor), end: _hcYMD(anchor));
    if (_patCalRange == 'week') {
      final dow = (anchor.weekday - 1) % 7;
      final start = anchor.subtract(Duration(days: dow));
      final end = start.add(const Duration(days: 6));
      return (start: _hcYMD(start), end: _hcYMD(end));
    }
    if (_patCalRange == 'month') {
      final start = DateTime(anchor.year, anchor.month, 1);
      final end = DateTime(anchor.year, anchor.month + 1, 0);
      return (start: _hcYMD(start), end: _hcYMD(end));
    }
    return null;
  }

  List<_CalDay> get _patCalDays => _buildDays(_patCalRangeBounds);
  String get _patCalRangeLabel => _rangeLabel(_patCalRangeBounds);

  List<Map> get _patCalPatientsForDisplay {
    if (_patCalPatientId != null) {
      return _patients.where((p) => p['id'] == _patCalPatientId).toList();
    }
    return _patients;
  }

  List<_PatCalRow> get _patCalRows {
    final days = _patCalDays;
    if (days.isEmpty) return [];
    return _patCalPatientsForDisplay.map((p) {
      final byDay = <String, List<Map>>{};
      final byDayMin = <String, int>{};
      var totalCareMin = 0;
      final cgSet = <int>{};
      for (final d in days) {
        byDay[d.iso] = [];
        byDayMin[d.iso] = 0;
      }
      for (final s in _shifts) {
        if (s['patient'] != p['id'] || s['status'] == 'cancelled') continue;
        final sd = hcSplitDateTime(s['start_at']).date;
        if (!byDay.containsKey(sd)) continue;
        byDay[sd]!.add(s);
        final mins = DateTime.parse(s['end_at']).difference(DateTime.parse(s['start_at'])).inMinutes;
        byDayMin[sd] = (byDayMin[sd] ?? 0) + mins;
        totalCareMin += mins;
        if (s['caregiver'] != null) cgSet.add(s['caregiver'] as int);
      }
      final byDayPct = <String, int>{};
      for (final d in days) {
        byDay[d.iso]!.sort((a, b) => DateTime.parse(a['start_at']).compareTo(DateTime.parse(b['start_at'])));
        byDayPct[d.iso] = ((byDayMin[d.iso]! / _patDayCapacityMin) * 100).round().clamp(0, 100);
      }
      final totalCapacityMin = days.length * _patDayCapacityMin;
      final coveragePct = totalCapacityMin > 0
          ? ((totalCareMin / totalCapacityMin) * 100).round().clamp(0, 100)
          : 0;
      return _PatCalRow(patient: p, byDay: byDay, byDayMin: byDayMin, byDayPct: byDayPct, totalCareMin: totalCareMin, coveragePct: coveragePct, uniqueCaregivers: cgSet.length);
    }).toList();
  }

  // ═════════════════════════════════════════════════════════
  //  TAB 4: PATIENT ASSIGNMENTS
  // ═════════════════════════════════════════════════════════

  List<Map> get _filteredCaregivers2 {
    final q = _cgSearch2.trim().toLowerCase();
    if (q.isEmpty) return _caregivers;
    return _caregivers.where((c) {
      final blob = '${c['user']?['full_name'] ?? ''} ${c['user']?['email'] ?? ''} ${c['license_number'] ?? ''}'.toLowerCase();
      return blob.contains(q);
    }).toList();
  }

  Map? get _selectedCaregiver =>
      _caregivers.cast<Map?>().firstWhere((c) => c?['id'] == _selectedCaregiverId, orElse: () => null);

  List<Map> get _filteredPatients {
    final q = _patientSearch.trim().toLowerCase();
    var out = _patients;
    if (_patientFilter == 'assigned') {
      out = out.where((p) => _currentAssigned.contains(p['id'] as int)).toList();
    } else if (_patientFilter == 'unassigned') {
      out = out.where((p) => !_currentAssigned.contains(p['id'] as int)).toList();
    }
    if (q.isEmpty) return out;
    return out.where((p) {
      final blob = '${p['user']?['full_name'] ?? ''} ${p['medical_record_number'] ?? ''} ${p['primary_diagnosis'] ?? ''}'.toLowerCase();
      return blob.contains(q);
    }).toList();
  }

  int get _pendingAddCount => _currentAssigned.where((id) => !_initialAssigned.contains(id)).length;
  int get _pendingRemoveCount => _initialAssigned.where((id) => !_currentAssigned.contains(id)).length;
  bool get _isDirty => _pendingAddCount > 0 || _pendingRemoveCount > 0;
  int get _primaryCount => _patients.where((p) => p['assigned_caregiver'] == _selectedCaregiverId).length;

  Future<void> _selectCaregiver(int id) async {
    if (_isDirty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('Unsaved changes'),
          content: const Text('You have unsaved changes. Discard them?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Discard')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _selectedCaregiverId = id);
    await _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    if (_selectedCaregiverId == null) return;
    setState(() => _loadingAssignments = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/homecare/caregivers/$_selectedCaregiverId/assigned-patients/');
      final list = (res.data is List ? res.data : (res.data?['results'] ?? [])) as List;
      final ids = list.cast<Map>().map((p) => p['id'] as int).toSet();
      setState(() {
        _initialAssigned = Set.from(ids);
        _currentAssigned = Set.from(ids);
      });
    } catch (_) {
      _snack('Failed to load assignments', hcRed);
    } finally {
      if (mounted) setState(() => _loadingAssignments = false);
    }
  }

  Future<void> _saveAssignments() async {
    if (_selectedCaregiverId == null || !_isDirty) return;
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final ids = _currentAssigned.where((id) {
        final p = _patients.firstWhere((x) => x['id'] == id, orElse: () => {});
        return !(p.isNotEmpty && p['assigned_caregiver'] == _selectedCaregiverId);
      }).toList();
      final res = await dio.post('/homecare/caregivers/$_selectedCaregiverId/set-patients/',
          data: {'patient_ids': ids});
      final added = (res.data['added'] as List?)?.length ?? 0;
      final removed = (res.data['removed'] as List?)?.length ?? 0;
      _snack('Saved · +$added added, -$removed removed', hcGreen);
      setState(() => _initialAssigned = Set.from(_currentAssigned));
      _loadAll();
    } catch (e) {
      _snack('Failed to save', hcRed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ═════════════════════════════════════════════════════════
  //  SHIFT ACTIONS (cancel, mark missed, reassign, delete)
  // ═════════════════════════════════════════════════════════

  Future<void> _cancelShift(Map s) async {
    final ok = await showDialog<bool>(
      context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('Cancel shift?'),
          content: Text("Cancel ${s['patient_name']}'s shift at ${hcTime(s['start_at'])}?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('No')),
            FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Yes')),
          ],
        ),
    );
    if (ok != true) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/homecare/schedules/${s['id']}/cancel/', data: {'reason': 'Cancelled from sheet'});
      _snack('Shift cancelled');
      _loadShifts();
    } catch (_) {
      _snack('Failed to cancel', hcRed);
    }
  }

  Future<void> _deleteShift(Map s) async {
    final ok = await showDialog<bool>(
      context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('Delete shift?'),
          content: Text('Delete shift with ${s['patient_name']}? This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: hcRed), onPressed: () => Navigator.pop(dCtx, true), child: const Text('Delete')),
          ],
        ),
    );
    if (ok != true) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/homecare/schedules/${s['id']}/');
      _snack('Shift deleted');
      _loadShifts();
    } catch (_) {
      _snack('Failed to delete', hcRed);
    }
  }

  void _openMarkMissed(Map s) {
    final reason = TextEditingController();
    final pin = TextEditingController();
    bool requestReassign = true;
    bool saving = false;
    final auth = ref.read(authProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(builder: (ctx, setSheetState) {
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: hcRed.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.person_off_rounded, color: hcRed, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Mark shift as missed', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text('${s['patient_name']} · ${hcTimeRange(s['start_at'], s['end_at'])}', style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              ])),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 20)),
            ]),
            const SizedBox(height: 14),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: hcRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Text('This will mark the shift as missed and request a replacement caregiver. Provide a reason and verify your identity.',
                  style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant))),
            const SizedBox(height: 14),
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason *', prefixIcon: Icon(Icons.message_rounded)), maxLines: 2),
            CheckboxListTile(value: requestReassign, onChanged: (v) => setSheetState(() => requestReassign = v ?? true),
              controlAffinity: ListTileControlAffinity.leading, title: const Text('Request reassignment to another caregiver', style: TextStyle(fontSize: 13)),
              contentPadding: EdgeInsets.zero, dense: true),
            const Divider(height: 20),
            Text('VERIFY IDENTITY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            HcPinField(controller: pin, myPin: auth.user?.pin),
            const SizedBox(height: 16),
            Row(children: [
              const Spacer(),
              TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: (reason.text.trim().isEmpty || pin.text.length < 4 || saving) ? null : () async {
                  setSheetState(() => saving = true);
                  try {
                    final dio = ref.read(dioProvider);
                    await dio.post('/homecare/schedules/${s['id']}/mark_missed/', data: {
                      'reason': reason.text.trim(), 'pin': pin.text, 'request_reassign': requestReassign,
                    });
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      _snack(requestReassign ? 'Marked missed — reassignment requested' : 'Shift marked as missed');
                      _loadShifts();
                    }
                  } catch (e) {
                    String msg = 'Failed to mark missed';
                    try { final data = (e as dynamic).response?.data; if (data is Map && data['detail'] != null) msg = data['detail'].toString(); } catch (_) {}
                    if (ctx.mounted) { setSheetState(() => saving = false); _snack(msg, hcRed); }
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: hcRed),
                icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.person_off_rounded, size: 18),
                label: const Text('Mark missed'),
              ),
            ]),
          ]),
        );
      }),
    );
  }

  void _openReassignDialog(Map s) {
    int? replacementId;
    final reasonCtrl = TextEditingController();
    String error = '';
    bool saving = false;

    final candidates = _caregivers.where((c) =>
        c['id'] != s['caregiver'] &&
        c['is_available'] != false &&
        c['employment_status'] != 'terminated').toList();

    final startMs = DateTime.parse(s['start_at'].toString());
    final endMs = DateTime.parse(s['end_at'].toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(builder: (ctx, setSheetState) {
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: hcAmber.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.swap_horiz_rounded, color: hcAmber, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Reassign missed shift', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text('${s['patient_name']} · ${hcTimeRange(s['start_at'], s['end_at'])}', style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              ])),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 20)),
            ]),
            const SizedBox(height: 14),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: hcAmber.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Text('This shift was missed and needs a replacement caregiver. Pick someone available to cover the same patient and time.',
                  style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant))),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              initialValue: replacementId,
              decoration: const InputDecoration(labelText: 'Replacement caregiver *', prefixIcon: Icon(Icons.favorite_rounded)),
              items: candidates.map((c) {
                final conflict = _shifts.any((x) =>
                    x['caregiver'] == c['id'] &&
                    x['id'] != s['id'] &&
                    x['status'] != 'cancelled' && x['status'] != 'missed' &&
                    DateTime.parse(x['start_at'].toString()).isBefore(endMs) &&
                    DateTime.parse(x['end_at'].toString()).isAfter(startMs));
                final label = '${c['user']?['full_name'] ?? c['user']?['email'] ?? 'Caregiver'} · ${hcCategoryLabel(c['category']?.toString())}'
                    '${conflict ? '  ⚠ busy' : '  ✓ available'}';
                return DropdownMenuItem<int>(value: c['id'] as int, child: Text(label, overflow: TextOverflow.ellipsis), enabled: !conflict);
              }).toList(),
              onChanged: (v) => setSheetState(() { replacementId = v; error = ''; }),
            ),
            if (error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error, style: TextStyle(color: hcRed, fontSize: 12.5))),
            const SizedBox(height: 10),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason / notes', prefixIcon: Icon(Icons.note_rounded)), maxLines: 2),
            const SizedBox(height: 16),
            Row(children: [
              const Spacer(),
              TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: (replacementId == null || saving) ? null : () async {
                  setSheetState(() { saving = true; error = ''; });
                  try {
                    final dio = ref.read(dioProvider);
                    await dio.post('/homecare/schedules/${s['id']}/reassign/', data: {
                      'caregiver': replacementId, 'start_at': s['start_at'], 'end_at': s['end_at'],
                    });
                    if (reasonCtrl.text.trim().isNotEmpty) {
                      try {
                        await dio.post('/homecare/schedules/${s['id']}/request-reassign/', data: {'reason': reasonCtrl.text.trim()});
                      } catch (_) {}
                    }
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      _snack('Shift reassigned', hcGreen);
                      _loadShifts();
                    }
                  } catch (e) {
                    String msg = 'Failed to reassign';
                    try { final data = (e as dynamic).response?.data; if (data is Map && data['detail'] != null) msg = data['detail'].toString(); } catch (_) {}
                    if (ctx.mounted) setSheetState(() { saving = false; error = msg; });
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: hcAmber),
                icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Reassign shift'),
              ),
            ]),
          ]),
        );
      }),
    );
  }

  void _openShiftDialog({Map? existing, Map? caregiver}) {
    showShiftDialog(
      context,
      caregivers: _caregivers,
      patients: _patients,
      allShifts: _shifts,
      existing: existing,
      preselectedCaregiver: caregiver,
      sheetDate: _sheetDate,
      onChanged: _loadShifts,
    );
  }

  // ═════════════════════════════════════════════════════════
  //  SHARED HELPERS
  // ═════════════════════════════════════════════════════════

  void _snack(String msg, [Color? color]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _hcYMD(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<_CalDay> _buildDays(({String start, String end})? bounds) {
    if (bounds == null) return [];
    final out = <_CalDay>[];
    final start = DateTime.tryParse('${bounds.start}T00:00');
    final end = DateTime.tryParse('${bounds.end}T00:00');
    if (start == null || end == null) return out;
    final today = _hcYMD(DateTime.now());
    for (DateTime d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final iso = _hcYMD(d);
      out.add(_CalDay(
        iso: iso,
        dow: DateFormat('EEE').format(d),
        dayNum: d.day,
        month: DateFormat('MMM').format(d),
        isToday: iso == today,
        isWeekend: d.weekday == 6 || d.weekday == 7,
      ));
    }
    return out;
  }

  String _rangeLabel(({String start, String end})? b) {
    if (b == null) return '';
    if (b.start == b.end) return hcFormatDateShort(b.start);
    return '${hcFormatDateShort(b.start)} – ${hcFormatDateShort(b.end)}';
  }

  void _calShiftRange(int dir) {
    final step = {'day': 1, 'week': 7, 'month': 30}[_calRange] ?? 7;
    if (_calRange == 'custom') {
      final s = DateTime.tryParse('$_calCustomStart\T00:00');
      final e = DateTime.tryParse('$_calCustomEnd\T00:00');
      if (s != null && e != null) {
        final width = e.difference(s).inDays + 1;
        setState(() {
          _calCustomStart = _hcYMD(s.add(Duration(days: dir * width)));
          _calCustomEnd = _hcYMD(e.add(Duration(days: dir * width)));
        });
      }
      return;
    }
    final a = DateTime.tryParse('$_calAnchor\T00:00');
    if (a == null) return;
    if (_calRange == 'month') {
      setState(() => _calAnchor = _hcYMD(DateTime(a.year, a.month + dir, a.day)));
    } else {
      setState(() => _calAnchor = _hcYMD(a.add(Duration(days: dir * step))));
    }
    _loadShifts();
  }

  void _calGoToday() {
    setState(() {
      _calAnchor = hcDateOffset(0);
      if (_calRange == 'custom') {
        _calCustomStart = hcDateOffset(0);
        _calCustomEnd = hcDateOffset(6);
      }
    });
    _loadShifts();
  }

  void _patCalShiftRange(int dir) {
    final step = {'day': 1, 'week': 7, 'month': 30}[_patCalRange] ?? 7;
    if (_patCalRange == 'custom') {
      final s = DateTime.tryParse('$_patCalCustomStart\T00:00');
      final e = DateTime.tryParse('$_patCalCustomEnd\T00:00');
      if (s != null && e != null) {
        final width = e.difference(s).inDays + 1;
        setState(() {
          _patCalCustomStart = _hcYMD(s.add(Duration(days: dir * width)));
          _patCalCustomEnd = _hcYMD(e.add(Duration(days: dir * width)));
        });
      }
      return;
    }
    final a = DateTime.tryParse('$_patCalAnchor\T00:00');
    if (a == null) return;
    if (_patCalRange == 'month') {
      setState(() => _patCalAnchor = _hcYMD(DateTime(a.year, a.month + dir, a.day)));
    } else {
      setState(() => _patCalAnchor = _hcYMD(a.add(Duration(days: dir * step))));
    }
    _loadShifts();
  }

  void _patCalGoToday() {
    setState(() {
      _patCalAnchor = hcDateOffset(0);
      if (_patCalRange == 'custom') {
        _patCalCustomStart = hcDateOffset(0);
        _patCalCustomEnd = hcDateOffset(6);
      }
    });
    _loadShifts();
  }

  void _openCustomRangeDialog(bool isPatient) {
    final startCtrl = TextEditingController(text: isPatient ? _patCalCustomStart : _calCustomStart);
    final endCtrl = TextEditingController(text: isPatient ? _patCalCustomEnd : _calCustomEnd);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(builder: (ctx, setSheetState) {
        return Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: hcPurple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.calendar_month_rounded, color: hcPurple, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Text('Custom date range', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 20)),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(context: ctx, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 730)),
                    initialDate: DateTime.tryParse('${startCtrl.text}T00:00') ?? DateTime.now());
                  if (d != null) setSheetState(() => startCtrl.text = _hcYMD(d));
                },
                icon: const Icon(Icons.calendar_today_rounded, size: 16), label: Text(startCtrl.text.isEmpty ? 'Start' : startCtrl.text, style: const TextStyle(fontSize: 12)),
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(context: ctx, firstDate: DateTime.tryParse('${startCtrl.text}T00:00') ?? DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 730)),
                    initialDate: DateTime.tryParse('${endCtrl.text}T00:00') ?? DateTime.now());
                  if (d != null) setSheetState(() => endCtrl.text = _hcYMD(d));
                },
                icon: const Icon(Icons.calendar_today_rounded, size: 16), label: Text(endCtrl.text.isEmpty ? 'End' : endCtrl.text, style: const TextStyle(fontSize: 12)),
              )),
            ]),
            const SizedBox(height: 14),
            Text('QUICK PRESETS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final p in const [('Next 7 days', 0, 6), ('Next 14 days', 0, 13), ('Next 30 days', 0, 29), ('Last 7 days', -6, 0), ('Last 30 days', -29, 0)])
                ActionChip(label: Text(p.$1, style: const TextStyle(fontSize: 12)), onPressed: () => setSheetState(() {
                  startCtrl.text = hcDateOffset(p.$2);
                  endCtrl.text = hcDateOffset(p.$3);
                })),
            ]),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: () {
                if (startCtrl.text.isEmpty || endCtrl.text.isEmpty || endCtrl.text.compareTo(startCtrl.text) < 0) return;
                setState(() {
                  if (isPatient) {
                    _patCalCustomStart = startCtrl.text;
                    _patCalCustomEnd = endCtrl.text;
                  } else {
                    _calCustomStart = startCtrl.text;
                    _calCustomEnd = endCtrl.text;
                  }
                });
                Navigator.pop(ctx);
                _loadShifts();
              },
              style: FilledButton.styleFrom(backgroundColor: hcPurple),
              icon: const Icon(Icons.check_rounded, size: 18), label: const Text('Apply range'),
            )),
          ]),
        );
      }),
    );
  }

  // ═════════════════════════════════════════════════════════
  //  BUILD
  // ═════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final availableNow = _caregivers.where((c) => _caregiverNowShift(c['id'] as int) == null && c['is_available'] != false).length;
    final engagedNow = _caregivers.where((c) => _caregiverNowShift(c['id'] as int) != null).length;
    final todayShifts = _shifts.where((s) {
      return hcSplitDateTime(s['start_at']).date == hcDateOffset(0) && s['status'] != 'cancelled';
    }).length;

    return Scaffold(
      body: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(child: _buildHero(availableNow, engagedNow, todayShifts)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: hcPurple,
                unselectedLabelColor: cs.onSurfaceVariant,
                indicatorColor: hcPurple,
                indicatorSize: TabBarIndicatorSize.label,
                isScrollable: true,
                tabs: const [
                  Tab(icon: Icon(Icons.assignment_rounded, size: 18), text: 'Shift sheets'),
                  Tab(icon: Icon(Icons.calendar_month_rounded, size: 18), text: 'Caregiver cal'),
                  Tab(icon: Icon(Icons.calendar_view_day_rounded, size: 18), text: 'Patient cal'),
                  Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Patient assign'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildShiftSheetsTab(cs),
            _buildCaregiverCalendarTab(cs),
            _buildPatientCalendarTab(cs),
            _buildPatientAssignmentsTab(cs),
          ],
        ),
      ),
    );
  }

  // ── Hero ──
  Widget _buildHero(int availableNow, int engagedNow, int todayShifts) {
    return HcHero(
      eyebrow: _isCaregiver ? 'MY SHIFTS' : 'HOMECARE · CARE OPERATIONS',
      title: _isCaregiver ? 'My shifts' : 'Assignment sheets',
      subtitle: 'Roster shifts, see who is free now, and assign caregivers to patients.',
      icon: Icons.swap_horiz_rounded,
      gradient: const [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFFA78BFA)],
      chips: [
        HcHeroChip(icon: Icons.favorite_rounded, label: '${_caregivers.length} caregivers'),
        HcHeroChip(icon: Icons.check_circle_rounded, label: '$availableNow available'),
        HcHeroChip(icon: Icons.access_time_rounded, label: '$engagedNow engaged'),
        HcHeroChip(icon: Icons.event_rounded, label: '$todayShifts shifts today'),
      ],
    );
  }

  // ── Tab 1: Shift Sheets ──
  Widget _buildShiftSheetsTab(ColorScheme cs) {
    if (_loadingCg) return const Center(child: CircularProgressIndicator());
    if (_filteredSheetCaregivers.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSheetFilters(cs),
          const SizedBox(height: 24),
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_off_rounded, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 8),
            Text('No caregivers match', style: TextStyle(color: cs.onSurfaceVariant)),
          ])),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      itemCount: _filteredSheetCaregivers.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0), child: _buildSheetFilters(cs));
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildCaregiverSheetCard(_filteredSheetCaregivers[i - 1], cs),
        );
      },
    );
  }

  Widget _buildSheetFilters(ColorScheme cs) {
    return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          TextField(
            decoration: const InputDecoration(labelText: 'Search caregivers…', prefixIcon: Icon(Icons.search_rounded), isDense: true),
            onChanged: (v) => setState(() => _cgSearch = v),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: DropdownButtonFormField<String>(
              initialValue: _sheetFilter, isDense: true, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'available', child: Text('Available', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'engaged', child: Text('Engaged', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'livein', child: Text('Live-in', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'off', child: Text('Off shift', style: TextStyle(fontSize: 13))),
              ],
              onChanged: (v) => setState(() => _sheetFilter = v ?? 'all'),
            )),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<String>(
              initialValue: _categoryFilter, isDense: true, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All roles', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'nurse', child: Text('Nurse', style: TextStyle(fontSize: 13))),
                DropdownMenuItem(value: 'hca', child: Text('HCA', style: TextStyle(fontSize: 13))),
              ],
              onChanged: (v) => setState(() => _categoryFilter = v ?? 'all'),
            )),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'yesterday', label: Text('Yest', style: TextStyle(fontSize: 12))),
                  ButtonSegment(value: 'today', label: Text('Today', style: TextStyle(fontSize: 12))),
                  ButtonSegment(value: 'tomorrow', label: Text('Tom', style: TextStyle(fontSize: 12))),
                ],
                selected: {_sheetDate == hcDateOffset(-1) ? 'yesterday' : _sheetDate == hcDateOffset(0) ? 'today' : _sheetDate == hcDateOffset(1) ? 'tomorrow' : 'custom'},
                onSelectionChanged: (s) {
                  setState(() {
                    if (s.first == 'yesterday') _sheetDate = hcDateOffset(-1);
                    if (s.first == 'today') _sheetDate = hcDateOffset(0);
                    if (s.first == 'tomorrow') _sheetDate = hcDateOffset(1);
                  });
                  _loadShifts();
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context, firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                  initialDate: DateTime.tryParse('$_sheetDate\T00:00') ?? DateTime.now(),
                );
                if (d != null) { setState(() => _sheetDate = _hcYMD(d)); _loadShifts(); }
              },
              icon: const Icon(Icons.calendar_today_rounded, size: 16),
            ),
            const SizedBox(width: 4),
            IconButton.outlined(
              onPressed: _loadingShifts ? null : _loadShifts,
              icon: _loadingShifts ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded, size: 16),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: () => _openShiftDialog(),
            style: FilledButton.styleFrom(backgroundColor: hcPurple, visualDensity: VisualDensity.compact),
            icon: const Icon(Icons.add_rounded, size: 18), label: const Text('New shift'),
          )),
        ],
      ),
    );
  }

  Widget _buildCaregiverSheetCard(Map c, ColorScheme cs) {
    final cgId = c['id'] as int;
    final catColor = hcCategoryColor(c['category']?.toString());
    final nowShift = _caregiverNowShift(cgId);
    final nextShift = _caregiverNextShift(cgId);
    final shifts = _shiftsForCaregiver(cgId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            HcAvatar(name: c['user']?['full_name'] ?? c['user']?['email'], color: catColor, size: 44),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['user']?['full_name'] ?? c['user']?['email'] ?? '—',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), overflow: TextOverflow.ellipsis),
              Row(children: [
                Icon(hcCategoryIcon(c['category']?.toString()), size: 12, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(hcCategoryLabel(c['category']?.toString()), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                if (c['license_number'] != null) ...[
                  const SizedBox(width: 4),
                  Text('· #${c['license_number']}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ]),
            ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              HcStatusChip(label: _availabilityLabel(c), color: _availabilityColor(c)),
            ]),
          ]),
          const SizedBox(height: 10),
          // Status line
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
            child: nowShift != null
              ? Row(children: [
                  Icon(Icons.access_time_rounded, size: 14, color: hcAmber),
                  const SizedBox(width: 6),
                  Expanded(child: Text.rich(TextSpan(children: [
                    const TextSpan(text: 'Engaged · with ', style: TextStyle(fontSize: 12.5)),
                    TextSpan(text: nowShift['patient_name']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    TextSpan(text: ' until ${hcTime(nowShift['end_at'])}', style: const TextStyle(fontSize: 12.5)),
                    if (nowShift['shift_type'] == 'live_in')
                      const TextSpan(text: ' · LIVE-IN', style: TextStyle(fontSize: 12.5, color: hcPurple, fontWeight: FontWeight.bold)),
                  ]))),
                ])
              : nextShift != null
                ? Row(children: [
                    Icon(Icons.schedule_rounded, size: 14, color: hcGreen),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Available · next shift ${hcFormatRelative(nextShift['start_at'])} with ${nextShift['patient_name']}', style: const TextStyle(fontSize: 12.5))),
                  ])
                : Row(children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: hcGreen),
                    const SizedBox(width: 6),
                    const Text('Available · no shifts on this day', style: TextStyle(fontSize: 12.5)),
                  ]),
          ),
          const SizedBox(height: 10),
          // Shift list header
          Text('${shifts.length} shift(s) on ${hcFormatDateShort(_sheetDate)}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
          const SizedBox(height: 4),
          if (shifts.isEmpty)
            Text('No shifts scheduled.', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
          else
            ...shifts.map((s) => _buildShiftRow(s, cs)),
          const Divider(height: 20),
          // Footer buttons
          Row(children: [
            Expanded(child: FilledButton.tonalIcon(
              onPressed: () => _openShiftDialog(caregiver: c),
              style: FilledButton.styleFrom(backgroundColor: hcPurple.withValues(alpha: 0.1), foregroundColor: hcPurple),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Assign shift', style: TextStyle(fontSize: 13)),
            )),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () { _tabController.animateTo(3); setState(() => _selectedCaregiverId = c['id'] as int); _loadAssignments(); },
              icon: const Icon(Icons.people_alt_rounded, size: 16),
              label: const Text('Patients', style: TextStyle(fontSize: 13)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildShiftRow(Map s, ColorScheme cs) {
    final status = s['status']?.toString() ?? '';
    final bucket = hcShiftBucket(s);
    final bucketColor = hcBucketColor(bucket);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bucketColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: bucketColor.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(hcShiftTypeIcon(s['shift_type']?.toString()), size: 16, color: hcShiftTypeColor(s['shift_type']?.toString())),
          const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['patient_name']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
            Text('${hcTimeRange(s['start_at'], s['end_at'])} · ${hcShiftTypeLabel(s['shift_type']?.toString())}'
                '${s['check_in_at'] != null ? ' · in @ ${hcTime(s['check_in_at'])}' : ''}'
                '${s['check_out_at'] != null ? ' · out @ ${hcTime(s['check_out_at'])}' : ''}',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ]),
          ),
          HcStatusChip(label: hcLabel(status), color: hcVisitStatusColor(status)),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 18),
            itemBuilder: (_) => [
              if (status == 'scheduled')
                const PopupMenuItem(value: 'checkin', child: ListTile(leading: Icon(Icons.login_rounded), title: Text('Check in'), dense: true)),
              if (status == 'checked_in')
                const PopupMenuItem(value: 'checkout', child: ListTile(leading: Icon(Icons.logout_rounded), title: Text('Check out'), dense: true)),
              if (status == 'missed')
                const PopupMenuItem(value: 'reassign', child: ListTile(leading: Icon(Icons.swap_horiz_rounded), title: Text('Reassign…'), dense: true)),
              const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Edit'), dense: true)),
              if (status == 'scheduled')
                const PopupMenuItem(value: 'cancel', child: ListTile(leading: Icon(Icons.cancel_rounded), title: Text('Cancel'), dense: true)),
              if (status == 'scheduled' || status == 'checked_in')
                const PopupMenuItem(value: 'missed', child: ListTile(leading: Icon(Icons.person_off_rounded), title: Text('Mark missed'), dense: true)),
              const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_rounded), title: Text('Delete'), dense: true)),
            ],
            onSelected: (action) {
              switch (action) {
                case 'checkin': showVisitCheckSheet(context, visit: s, action: 'in', onDone: _loadShifts);
                case 'checkout': showVisitCheckSheet(context, visit: s, action: 'out', onDone: _loadShifts);
                case 'reassign': _openReassignDialog(s);
                case 'edit': _openShiftDialog(existing: s);
                case 'cancel': _cancelShift(s);
                case 'missed': _openMarkMissed(s);
                case 'delete': _deleteShift(s);
              }
            },
          ),
        ]),
        // Quick action buttons
        if (status == 'scheduled')
          Padding(padding: const EdgeInsets.only(top: 6), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            FilledButton.tonalIcon(
              onPressed: () => showVisitCheckSheet(context, visit: s, action: 'in', onDone: _loadShifts),
              icon: const Icon(Icons.login_rounded, size: 16),
              label: const Text('Check in', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(backgroundColor: hcGreen.withValues(alpha: 0.1), foregroundColor: hcGreen),
            ),
          ]))
        else if (status == 'checked_in')
          Padding(padding: const EdgeInsets.only(top: 6), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            FilledButton.tonalIcon(
              onPressed: () => showVisitCheckSheet(context, visit: s, action: 'out', onDone: _loadShifts),
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Check out', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(backgroundColor: hcBlue.withValues(alpha: 0.1), foregroundColor: hcBlue),
            ),
          ]))
        else if (status == 'missed' && s['reassigned_to'] == null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            FilledButton.tonalIcon(
              onPressed: () => _openReassignDialog(s),
              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
              label: const Text('Reassign', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(backgroundColor: hcAmber.withValues(alpha: 0.1), foregroundColor: hcAmber),
            ),
          ])),
        // Missed footer
        if (status == 'missed' && s['reassignment_requested'] == true && s['reassigned_to'] == null)
          Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
            Icon(Icons.warning_rounded, size: 12, color: hcAmber),
            const SizedBox(width: 4),
            Text('Awaiting reassignment${s['reassignment_reason'] != null ? ' · ${s['reassignment_reason']}' : ''}',
                style: TextStyle(fontSize: 11, color: hcAmber)),
          ]))
        else if (s['reassigned_to'] != null)
          Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
            Icon(Icons.check_rounded, size: 12, color: hcGreen),
            const SizedBox(width: 4),
            Text('Reassigned (#${s['reassigned_to']})', style: TextStyle(fontSize: 11, color: hcGreen)),
          ])),
      ]),
    );
  }

  // ── Tab 2: Caregiver Calendar ──
  Widget _buildCaregiverCalendarTab(ColorScheme cs) {
    final rows = _calRows;
    final days = _calDays;
    final totalShifts = rows.fold(0, (a, r) => a + r.byDay.values.fold(0, (b, l) => b + l.length));
    final totalEngagedMin = rows.fold(0, (a, r) => a + r.totalEngagedMin);
    final capacity = rows.length * days.length * _calDayCapacityMin;
    final util = capacity > 0 ? ((totalEngagedMin / capacity) * 100).round().clamp(0, 100) : 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      children: [
        _buildCalToolbar(cs, isPatient: false),
        const SizedBox(height: 8),
        _buildCalStats([
          _StatItem('Caregivers', rows.length.toString(), Icons.favorite_rounded, hcPurple),
          _StatItem('Days', days.length.toString(), Icons.calendar_view_week_rounded, hcIndigo),
          _StatItem('Shifts', totalShifts.toString(), Icons.assignment_rounded, hcTeal, '${hcFormatHours(totalEngagedMin)} engaged'),
          _StatItem('Avg util', '$util%', Icons.pie_chart_rounded, util > 80 ? hcRed : util > 50 ? hcAmber : hcGreen, '${hcFormatHours((rows.length * days.length * _calDayCapacityMin) - totalEngagedMin)} free'),
        ]),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _loadingShifts && rows.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            : rows.isEmpty
              ? Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('No caregivers to show.', style: TextStyle(color: cs.onSurfaceVariant))))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildCalendarGrid(days, rows.map((r) => _GridRow(
                    id: r.caregiver['id'],
                    name: r.caregiver['user']?['full_name'] ?? r.caregiver['user']?['email'] ?? '—',
                    sub: hcCategoryLabel(r.caregiver['category']?.toString()),
                    extra: '${hcFormatHours(r.totalEngagedMin)} · ${r.utilization}% util',
                    avatarColor: hcCategoryColor(r.caregiver['category']?.toString()),
                    byDay: r.byDay,
                    byDayPct: r.byDayPct,
                    byDayMin: r.byDayMin,
                    capacity: _calDayCapacityMin,
                    emptyLabel: 'Free',
                    barColorFn: hcAvailColor,
                  )).toList(), cs, showCaregiverName: false),
                ),
        ),
      ],
    );
  }

  // ── Tab 3: Patient Calendar ──
  Widget _buildPatientCalendarTab(ColorScheme cs) {
    final rows = _patCalRows;
    final days = _patCalDays;
    final totalShifts = rows.fold(0, (a, r) => a + r.byDay.values.fold(0, (b, l) => b + l.length));
    final totalCareMin = rows.fold(0, (a, r) => a + r.totalCareMin);
    final capacity = rows.length * days.length * _patDayCapacityMin;
    final coverage = capacity > 0 ? ((totalCareMin / capacity) * 100).round().clamp(0, 100) : 0;
    final uncovered = rows.fold(0, (a, r) => a + r.byDay.values.where((l) => l.isEmpty).length);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
      children: [
        _buildCalToolbar(cs, isPatient: true),
        const SizedBox(height: 8),
        _buildCalStats([
          _StatItem('Patients', rows.length.toString(), Icons.people_alt_rounded, hcPurple),
          _StatItem('Days', days.length.toString(), Icons.calendar_view_week_rounded, hcIndigo),
          _StatItem('Visits', totalShifts.toString(), Icons.assignment_rounded, hcTeal, '${hcFormatHours(totalCareMin)} care'),
          _StatItem('Coverage', '$coverage%', Icons.shield_rounded, coverage >= 50 ? hcGreen : coverage >= 25 ? hcAmber : hcRed, '$uncovered uncovered'),
        ]),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _loadingShifts && rows.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            : rows.isEmpty
              ? Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('No patients to show.', style: TextStyle(color: cs.onSurfaceVariant))))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _buildCalendarGrid(days, rows.map((r) => _GridRow(
                    id: r.patient['id'],
                    name: r.patient['user']?['full_name'] ?? r.patient['user']?['email'] ?? '—',
                    sub: 'MRN ${r.patient['medical_record_number'] ?? '—'}${r.patient['risk_level'] != null ? ' · ${r.patient['risk_level']} risk' : ''}',
                    extra: '${hcFormatHours(r.totalCareMin)} · ${r.coveragePct}% covered · ${r.uniqueCaregivers} CG(s)',
                    avatarColor: hcRiskColor(r.patient['risk_level']?.toString()),
                    byDay: r.byDay,
                    byDayPct: r.byDayPct,
                    byDayMin: r.byDayMin,
                    capacity: _patDayCapacityMin,
                    emptyLabel: 'Uncovered',
                    barColorFn: hcCoverageColor,
                  )).toList(), cs, showCaregiverName: true),
                ),
        ),
      ],
    );
  }

  // ── Calendar Grid Widget ──
  Widget _buildCalendarGrid(List<_CalDay> days, List<_GridRow> rows, ColorScheme cs, {bool showCaregiverName = false}) {
    final nameColWidth = 180.0;
    final dayColWidth = 120.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(children: [
          SizedBox(
            width: nameColWidth,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text('Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant))),
          ),
          ...days.map((d) => Container(
            width: dayColWidth,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: d.isToday ? hcPurple.withValues(alpha: 0.1) : d.isWeekend ? cs.surfaceContainerHighest.withValues(alpha: 0.3) : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(children: [
              Text(d.dow, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              Text('${d.dayNum}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              Text(d.month, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ]),
          )),
        ]),
        // Body rows
        ...rows.map((row) => Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Name column
            SizedBox(width: nameColWidth, child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  HcAvatar(name: row.name, color: row.avatarColor, size: 32),
                  const SizedBox(width: 8),
                  Expanded(child: Text(row.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5), overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 2),
                Text(row.sub, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                Text(row.extra, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis),
              ]),
            )),
            // Day cells
            ...days.map((d) {
              final dayShifts = row.byDay[d.iso] ?? [];
              final pct = row.byDayPct[d.iso] ?? 0;
              final mins = row.byDayMin[d.iso] ?? 0;
              return Container(
                width: dayColWidth,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: d.isToday ? hcPurple.withValues(alpha: 0.06) : d.isWeekend ? cs.surfaceContainerHighest.withValues(alpha: 0.2) : null,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (dayShifts.isEmpty)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Center(child: Text(row.emptyLabel, style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: cs.onSurfaceVariant))))
                  else
                    ...dayShifts.take(3).map((s) {
                      final bucket = hcShiftBucket(s);
                      final bucketColor = hcBucketColor(bucket);
                      return GestureDetector(
                        onTap: () => _openShiftDialog(existing: s),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 3),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: bucketColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5), border: Border.all(color: bucketColor.withValues(alpha: 0.25))),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Icon(hcShiftTypeIcon(s['shift_type']?.toString()), size: 10, color: hcShiftTypeColor(s['shift_type']?.toString())),
                              const SizedBox(width: 3),
                              Expanded(child: Text(
                                showCaregiverName ? (s['caregiver_name']?.toString() ?? '—') : (s['patient_name']?.toString() ?? '—'),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis,
                              )),
                            ]),
                            Text('${hcTime(s['start_at'])}–${hcTime(s['end_at'])}', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                            HcStatusChip(label: hcLabel(s['status']?.toString()), color: hcVisitStatusColor(s['status']?.toString())),
                          ]),
                        ),
                      );
                    }),
                  if (dayShifts.length > 3)
                    Text('+${dayShifts.length - 3} more', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  // Availability bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 3,
                      backgroundColor: cs.surfaceContainerHighest,
                      color: row.barColorFn(pct),
                    ),
                  ),
                  Text('${hcFormatHours(mins)} · ${100 - pct}% free', style: TextStyle(fontSize: 8, color: cs.onSurfaceVariant)),
                ]),
              );
            }),
          ]),
        )),
      ],
    );
  }

  Widget _buildCalStats(List<_StatItem> stats) {
    return SizedBox(
      height: 76,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: stats.map((s) => Container(
          width: 140,
          margin: const EdgeInsets.only(right: 8),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: s.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Icon(s.icon, color: s.color, size: 16)),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(s.label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  Text(s.value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  if (s.sub != null) Text(s.sub!, style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ])),
              ]),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildCalToolbar(ColorScheme cs, {required bool isPatient}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        DropdownButtonFormField<int>(
          initialValue: isPatient ? _patCalPatientId : _calCaregiverId,
          decoration: InputDecoration(
            labelText: isPatient ? 'Patient' : 'Caregiver',
            prefixIcon: const Icon(Icons.search_rounded), isDense: true),
          items: [DropdownMenuItem<int>(value: null, child: Text(isPatient ? 'All patients' : 'All caregivers', style: const TextStyle(fontSize: 13)))]
            ..addAll((isPatient ? _patients : _caregivers).map((c) => DropdownMenuItem<int>(
              value: c['id'] as int,
              child: Text('${c['user']?['full_name'] ?? c['user']?['email'] ?? (isPatient ? 'Patient' : 'Caregiver')}'
                  '${c['medical_record_number'] != null ? ' · ${c['medical_record_number']}' : ''}'
                  '${!isPatient ? ' · ${hcCategoryLabel(c['category']?.toString())}' : ''}',
                  overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            ))),
          onChanged: (v) => setState(() {
            if (isPatient) { _patCalPatientId = v; } else { _calCaregiverId = v; }
          }),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            initialValue: isPatient ? _patCalRange : _calRange,
            isDense: true, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            items: const [
              DropdownMenuItem(value: 'day', child: Text('Today', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'week', child: Text('This week', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'month', child: Text('This month', style: TextStyle(fontSize: 13))),
              DropdownMenuItem(value: 'custom', child: Text('Custom', style: TextStyle(fontSize: 13))),
            ],
            onChanged: (v) {
              setState(() {
                if (isPatient) { _patCalRange = v ?? 'week'; } else { _calRange = v ?? 'week'; }
              });
              if (v == 'custom') _openCustomRangeDialog(isPatient);
              else _loadShifts();
            },
          )),
          const SizedBox(width: 8),
          IconButton.outlined(onPressed: () => isPatient ? _patCalShiftRange(-1) : _calShiftRange(-1), icon: const Icon(Icons.chevron_left_rounded, size: 20)),
          IconButton.outlined(onPressed: () => isPatient ? _patCalShiftRange(1) : _calShiftRange(1), icon: const Icon(Icons.chevron_right_rounded, size: 20)),
          IconButton.outlined(onPressed: isPatient ? _patCalGoToday : _calGoToday, icon: const Icon(Icons.today_rounded, size: 18)),
        ]),
        const SizedBox(height: 4),
        Text(isPatient ? _patCalRangeLabel : _calRangeLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        if ((isPatient ? _patCalRange : _calRange) == 'custom')
          TextButton.icon(
            onPressed: () => _openCustomRangeDialog(isPatient),
            icon: const Icon(Icons.edit_calendar_rounded, size: 16),
            label: Text('${isPatient ? _patCalCustomStart : _calCustomStart} → ${isPatient ? _patCalCustomEnd : _calCustomEnd}', style: const TextStyle(fontSize: 12)),
          ),
      ]),
    );
  }

  // ── Tab 4: Patient Assignments ──
  Widget _buildPatientAssignmentsTab(ColorScheme cs) {
    return Row(children: [
      // Left: caregiver picker
      SizedBox(
        width: 160,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: const InputDecoration(labelText: 'Search', prefixIcon: Icon(Icons.search_rounded, size: 16), isDense: true),
              onChanged: (v) => setState(() => _cgSearch2 = v),
            ),
          ),
          Expanded(child: _loadingCg
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _filteredCaregivers2.length,
                itemBuilder: (ctx, i) {
                  final c = _filteredCaregivers2[i];
                  final active = _selectedCaregiverId == c['id'];
                  return GestureDetector(
                    onTap: () => _selectCaregiver(c['id'] as int),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: active ? hcPurple.withValues(alpha: 0.1) : null,
                        border: active ? Border.all(color: hcPurple.withValues(alpha: 0.3)) : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        HcAvatar(name: c['user']?['full_name'] ?? c['user']?['email'], color: hcCategoryColor(c['category']?.toString()), size: 32),
                        const SizedBox(width: 6),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c['user']?['full_name'] ?? c['user']?['email'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                          Text('${hcCategoryLabel(c['category']?.toString())} · ${c['active_patients_count'] ?? 0} pts',
                              style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                        ]),
                        ),
                        if (active) Icon(Icons.chevron_right_rounded, color: hcPurple, size: 18),
                      ]),
                    ),
                  );
                },
              )),
        ]),
      ),
      // Right: patient list
      Expanded(child: _selectedCaregiverId == null
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.arrow_back_rounded, size: 48, color: hcPurple.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            const Text('Select a caregiver', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text('Choose a caregiver on the left to manage their patients.', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ]))
        : Column(children: [
            // Header card
            Card(
              margin: const EdgeInsets.fromLTRB(8, 0, 16, 8),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (_selectedCaregiver != null) HcAvatar(name: _selectedCaregiver!['user']?['full_name'], color: hcCategoryColor(_selectedCaregiver!['category']?.toString()), size: 36),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_selectedCaregiver?['user']?['full_name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13), overflow: TextOverflow.ellipsis),
                      Text('${hcCategoryLabel(_selectedCaregiver?['category']?.toString())} · ${_currentAssigned.length} patient(s) selected'
                          '${_primaryCount > 0 ? ' · $_primaryCount primary' : ''}',
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ]),
                    ),
                    IconButton(onPressed: _loadingAssignments ? null : _loadAssignments, icon: _loadingAssignments ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded, size: 18)),
                    FilledButton.icon(
                      onPressed: (_isDirty && !_saving) ? _saveAssignments : null,
                      style: FilledButton.styleFrom(backgroundColor: hcPurple, visualDensity: VisualDensity.compact),
                      icon: _saving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded, size: 16),
                      label: const Text('Save', style: TextStyle(fontSize: 13)),
                    ),
                  ]),
                  if (_isDirty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: hcAmber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text('Unsaved changes — $_pendingAddCount to add, $_pendingRemoveCount to remove.',
                            style: TextStyle(fontSize: 12, color: hcAmber)),
                      ),
                    ),
                ]),
              ),
            ),
            // Patient filter bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
              child: Row(children: [
                Expanded(child: TextField(
                  decoration: const InputDecoration(labelText: 'Search patients…', prefixIcon: Icon(Icons.search_rounded, size: 16), isDense: true),
                  onChanged: (v) => setState(() => _patientSearch = v),
                )),
                const SizedBox(width: 8),
                DropdownButtonFormField<String>(
                  initialValue: _patientFilter, isDense: true, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'assigned', child: Text('Assigned', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'unassigned', child: Text('Unassigned', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) => setState(() => _patientFilter = v ?? 'all'),
                ),
              ]),
            ),
            // Patient list
            Expanded(child: _loadingAssignments
              ? const Center(child: CircularProgressIndicator())
              : _filteredPatients.isEmpty
                ? Center(child: Text('No patients match.', style: TextStyle(color: cs.onSurfaceVariant)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 16, 24),
                    itemCount: _filteredPatients.length,
                    itemBuilder: (ctx, i) {
                      final p = _filteredPatients[i];
                      final pid = p['id'] as int;
                      final assigned = _currentAssigned.contains(pid);
                      final isPrimary = p['assigned_caregiver'] == _selectedCaregiverId;
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (_currentAssigned.contains(pid)) {
                            _currentAssigned.remove(pid);
                          } else {
                            _currentAssigned.add(pid);
                          }
                        }),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          color: assigned ? hcPurple.withValues(alpha: 0.05) : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: assigned ? BorderSide(color: hcPurple.withValues(alpha: 0.3)) : BorderSide.none,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Row(children: [
                              Checkbox(
                                value: assigned,
                                onChanged: (v) => setState(() {
                                  if (v == true) { _currentAssigned.add(pid); } else { _currentAssigned.remove(pid); }
                                }),
                                activeColor: hcPurple,
                              ),
                              HcAvatar(name: p['user']?['full_name'], color: hcRiskColor(p['risk_level']?.toString()), size: 32),
                              const SizedBox(width: 8),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Text(p['user']?['full_name'] ?? p['medical_record_number'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5), overflow: TextOverflow.ellipsis),
                                  if (isPrimary) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.star_rounded, size: 14, color: hcAmber),
                                  ],
                                ]),
                                Text('${p['medical_record_number'] ?? '—'}${p['primary_diagnosis'] != null ? ' · ${p['primary_diagnosis']}' : ''}',
                                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                              ]),
                              ),
                              if (p['risk_level'] != null)
                                HcStatusChip(label: p['risk_level'].toString(), color: hcRiskColor(p['risk_level']?.toString())),
                            ]),
                          ),
                        ),
                      );
                    },
                  )),
          ])),
    ]);
  }
}

// ═════════════════════════════════════════════════════════
//  Helper data classes
// ═════════════════════════════════════════════════════════

class _CalDay {
  final String iso;
  final String dow;
  final int dayNum;
  final String month;
  final bool isToday;
  final bool isWeekend;
  const _CalDay({required this.iso, required this.dow, required this.dayNum, required this.month, required this.isToday, required this.isWeekend});
}

class _CalRow {
  final Map caregiver;
  final Map<String, List<Map>> byDay;
  final Map<String, int> byDayMin;
  final Map<String, int> byDayPct;
  final int totalEngagedMin;
  final int utilization;
  const _CalRow({required this.caregiver, required this.byDay, required this.byDayMin, required this.byDayPct, required this.totalEngagedMin, required this.utilization});
}

class _PatCalRow {
  final Map patient;
  final Map<String, List<Map>> byDay;
  final Map<String, int> byDayMin;
  final Map<String, int> byDayPct;
  final int totalCareMin;
  final int coveragePct;
  final int uniqueCaregivers;
  const _PatCalRow({required this.patient, required this.byDay, required this.byDayMin, required this.byDayPct, required this.totalCareMin, required this.coveragePct, required this.uniqueCaregivers});
}

class _GridRow {
  final dynamic id;
  final String name;
  final String sub;
  final String extra;
  final Color avatarColor;
  final Map<String, List<Map>> byDay;
  final Map<String, int> byDayPct;
  final Map<String, int> byDayMin;
  final int capacity;
  final String emptyLabel;
  final Color Function(int) barColorFn;
  const _GridRow({required this.id, required this.name, required this.sub, required this.extra, required this.avatarColor, required this.byDay, required this.byDayPct, required this.byDayMin, required this.capacity, required this.emptyLabel, required this.barColorFn});
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? sub;
  const _StatItem(this.label, this.value, this.icon, this.color, [this.sub]);
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }
  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
