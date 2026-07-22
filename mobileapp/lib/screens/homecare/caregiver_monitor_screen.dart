import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import 'hc_common.dart';
import 'analytics/hc_analytics_common.dart';

// ═══════════════════════════════════════════════════════════════════
//  Caregiver Monitor — real-time command centre for caregiver
//  schedules, check-ins and field locations.
//  Mobile port of nuxtfrontend /homecare/caregiver-monitor.
// ═══════════════════════════════════════════════════════════════════

// ── Palette (mirrors web caregiver-monitor.vue exactly) ──
const _cmIndigo = Color(0xFF6366F1);
const _cmSky = Color(0xFF0EA5E9);
const _cmGreen = Color(0xFF22C55E);
const _cmGreenDeep = Color(0xFF10B981);
const _cmAmber = Color(0xFFF59E0B);
const _cmAmberDeep = Color(0xFFB45309);
const _cmPurple = Color(0xFF8B5CF6);
const _cmPink = Color(0xFFEC4899);
const _cmTeal = Color(0xFF14B8A6);
const _cmBlue = Color(0xFF3B82F6);
const _cmBlueDeep = Color(0xFF1D4ED8);
const _cmRed = Color(0xFFEF4444);
const _cmSlate = Color(0xFF94A3B8);
const _cmSlateDeep = Color(0xFF64748B);
const _cmNurse = Color(0xFF6366F1);
const _cmHca = Color(0xFFEC4899);

// ── Schedule status metadata ──
class _StatusMeta {
  final String label;
  final IconData icon;
  final Color color;
  final List<Color> gradient;
  const _StatusMeta(this.label, this.icon, this.color, this.gradient);
}

const _statusMeta = <String, _StatusMeta>{
  'scheduled': _StatusMeta('Scheduled', Icons.calendar_month_rounded, _cmBlue,
      [_cmBlueDeep, _cmBlue]),
  'checked_in': _StatusMeta('In progress', Icons.update_rounded, _cmTeal,
      [Color(0xFF0F766E), _cmTeal]),
  'completed': _StatusMeta('Completed', Icons.check_circle_rounded, _cmGreen,
      [Color(0xFF15803D), _cmGreen]),
  'missed': _StatusMeta('Missed', Icons.warning_amber_rounded, _cmAmber,
      [_cmAmberDeep, _cmAmber]),
  'cancelled': _StatusMeta('Cancelled', Icons.cancel_rounded, _cmSlate,
      [Color(0xFF475569), _cmSlate]),
};

_StatusMeta _sm(String? s) => _statusMeta[s] ?? _statusMeta['cancelled']!;

// ── Caregiver category helpers ──
Color _catColor(String? c) => switch (c) {
      'nurse' => _cmNurse,
      'hca' => _cmHca,
      _ => hcTeal,
    };

String _catLabel(String? c) => switch (c) {
      'nurse' => 'Nurse',
      'hca' => 'HCA',
      _ => 'Caregiver',
    };

String _shiftLabel(String? t) => switch (t) {
      'visit' => 'Single Visit',
      'live_in' => 'Live-in',
      'on_call' => 'On Call',
      _ => (t ?? 'Visit'),
    };

Color _adherenceColor(num rate) {
  if (rate >= 90) return _cmGreenDeep;
  if (rate >= 75) return _cmAmber;
  if (rate >= 50) return Color(0xFFEA580C);
  return _cmRed;
}

const _leaderColors = [
  _cmAmber, _cmPurple, _cmTeal, _cmSky, _cmBlue, _cmPink, _cmIndigo,
  _cmGreenDeep, Color(0xFF06B6D4), Color(0xFFF97316),
];

String _fmtTime(dynamic iso) {
  final d = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
  return d == null ? '' : DateFormat('HH:mm').format(d);
}

String _fmtDateTime(dynamic iso) {
  final d = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
  return d == null ? '—' : DateFormat('dd MMM, HH:mm').format(d);
}

String _duration(dynamic a, dynamic b) {
  final da = DateTime.tryParse(a?.toString() ?? '');
  final db = DateTime.tryParse(b?.toString() ?? '');
  if (da == null || db == null) return '—';
  final m = db.difference(da).inMinutes;
  if (m < 0) return '—';
  final h = m ~/ 60, mm = m % 60;
  return h > 0 ? '${h}h ${mm}m' : '${mm}m';
}

String _gpsShort(Map? g) {
  if (g == null || g['lat'] == null) return '—';
  final lat = (g['lat'] as num?)?.toDouble();
  final lng = (g['lng'] as num?)?.toDouble();
  if (lat == null || lng == null) return '—';
  return '${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}';
}

// ── Date window (mirrors web computeWindow) ──
({DateTime start, DateTime end}) _computeWindow(String range,
    {String? customFrom, String? customTo}) {
  final now = DateTime.now();
  DateTime start, end;
  if (range == 'custom' &&
      (customFrom?.isNotEmpty ?? false) &&
      (customTo?.isNotEmpty ?? false)) {
    start = DateTime.parse('${customFrom!}T00:00:00');
    end = DateTime.parse('${customTo!}T23:59:59');
  } else if (range == 'today') {
    start = DateTime(now.year, now.month, now.day);
    end = now;
  } else if (range == 'yesterday') {
    start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
    end = start.add(const Duration(hours: 23, minutes: 59, seconds: 59));
  } else if (range == '7d') {
    start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    end = now;
  } else if (range == '30d') {
    start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
    end = now;
  } else if (range == '90d') {
    start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 89));
    end = now;
  } else if (range == '1y') {
    start = DateTime(now.year - 1, now.month, now.day);
    end = now;
  } else {
    start = DateTime(now.year - 5, now.month, now.day);
    end = now;
  }
  return (start: start, end: end);
}

// ── Analytics data containers ──
class _MonitorData {
  final List<Map> caregivers;
  final List<Map> schedules;
  final List<Map> doses;
  const _MonitorData(this.caregivers, this.schedules, this.doses);
}

class _Kpis {
  final int total, inProgress, completed, missed, cancelled, checkedInOnMap;
  final int completionRate, missedRate, activeCaregivers;
  final String avgDuration;
  const _Kpis({
    required this.total,
    required this.inProgress,
    required this.completed,
    required this.missed,
    required this.cancelled,
    required this.checkedInOnMap,
    required this.completionRate,
    required this.missedRate,
    required this.activeCaregivers,
    required this.avgDuration,
  });
}

class _PerCaregiver {
  final int id;
  final String? name;
  final String? category;
  final int total, completed, missed, inProgress, checkIns, onTime;
  final int durSumMs, durCnt;
  const _PerCaregiver({
    required this.id,
    this.name,
    this.category,
    this.total = 0,
    this.completed = 0,
    this.missed = 0,
    this.inProgress = 0,
    this.checkIns = 0,
    this.onTime = 0,
    this.durSumMs = 0,
    this.durCnt = 0,
  });
  double get avgDurationHours => durCnt > 0 ? durSumMs / durCnt / 3600000 : 0;
}

class _DoseAgg {
  final int id;
  final String? name;
  final String? category;
  final int total, taken, missed, skipped, notGiven, refused, pending;
  final int autoMissed, onTime, takenWithTime, patients, finalized;
  final int adherenceRate, onTimeRate;
  const _DoseAgg({
    required this.id,
    this.name,
    this.category,
    this.total = 0,
    this.taken = 0,
    this.missed = 0,
    this.skipped = 0,
    this.notGiven = 0,
    this.refused = 0,
    this.pending = 0,
    this.autoMissed = 0,
    this.onTime = 0,
    this.takenWithTime = 0,
    this.patients = 0,
    this.finalized = 0,
    this.adherenceRate = 0,
    this.onTimeRate = 0,
  });
}

class _DoseKpis {
  final int total, taken, missed, skipped, refused, notGiven, pending;
  final int autoMissed, administered, finalized;
  final int adherenceRate;
  const _DoseKpis({
    this.total = 0,
    this.taken = 0,
    this.missed = 0,
    this.skipped = 0,
    this.refused = 0,
    this.notGiven = 0,
    this.pending = 0,
    this.autoMissed = 0,
    this.administered = 0,
    this.finalized = 0,
    this.adherenceRate = 0,
  });
}

// ═══════════════════════════════════════════════════════════════════
//  Provider — fetches caregivers + schedules + doses for the window.
//  The family key encodes the date window so changing the range
//  re-fetches automatically (mirrors web reload()).
// ═══════════════════════════════════════════════════════════════════
class _MonitorKey {
  final String range;
  final String? from;
  final String? to;
  const _MonitorKey(this.range, [this.from, this.to]);

  @override
  bool operator ==(Object other) =>
      other is _MonitorKey &&
      other.range == range &&
      other.from == from &&
      other.to == to;
  @override
  int get hashCode => Object.hash(range, from, to);
}

final _monitorProvider =
    FutureProvider.autoDispose.family<_MonitorData, _MonitorKey>((ref, key) async {
  final dio = ref.read(dioProvider);
  final w = _computeWindow(key.range, customFrom: key.from, customTo: key.to);

  // Fire-and-forget auto-expire so overdue doses are marked missed.
  try {
    await dio.post('/homecare/doses/auto_expire/');
  } catch (_) {/* non-fatal */}

  final results = await Future.wait([
    hcFetchAll(ref, '/homecare/caregivers/', params: {'page_size': 500}),
    hcFetchAll(ref, '/homecare/schedules/', params: {
      'page_size': 1000,
      'start_after': w.start.toIso8601String(),
      'end_before': w.end.toIso8601String(),
    }),
    hcFetchAll(ref, '/homecare/doses/', params: {
      'page_size': 1000,
      'from': w.start.toIso8601String(),
      'to': w.end.toIso8601String(),
      'ordering': 'scheduled_at',
    }),
  ]);

  final caregivers = results[0].cast<Map>();
  final schedules = results[1].cast<Map>();
  final doses = results[2].cast<Map>();

  // Backfill category + caregiver_category.
  for (final c in caregivers) {
    if (c['category'] == null && c['caregiver_category'] != null) {
      c['category'] = c['caregiver_category'];
    }
  }
  for (final s in schedules) {
    if (s['caregiver_category'] == null) {
      final m = caregivers.cast<Map?>().firstWhere(
          (c) => c?['id'] == s['caregiver'],
          orElse: () => null);
      if (m != null) s['caregiver_category'] = m['category'];
    }
  }

  return _MonitorData(caregivers, schedules, doses);
});

// ═══════════════════════════════════════════════════════════════════
//  Pure analytics computations (mirrors web computed properties).
// ═══════════════════════════════════════════════════════════════════
List<Map> _filterSchedules(List<Map> all, String? statusFilter,
    int? caregiverFilter, String search) {
  final q = search.trim().toLowerCase();
  return all.where((s) {
    if (statusFilter != null && s['status'] != statusFilter) return false;
    if (caregiverFilter != null && s['caregiver'] != caregiverFilter) return false;
    if (q.isNotEmpty) {
      final blob = [s['caregiver_name'], s['patient_name'], s['notes']]
          .whereType<String>()
          .join(' ')
          .toLowerCase();
      if (!blob.contains(q)) return false;
    }
    return true;
  }).toList();
}

_Kpis _computeKpis(List<Map> list) {
  final total = list.length;
  final inProgress = list.where((s) => s['status'] == 'checked_in').length;
  final completed = list.where((s) => s['status'] == 'completed').length;
  final missed = list.where((s) => s['status'] == 'missed').length;
  final cancelled = list.where((s) => s['status'] == 'cancelled').length;
  final checkedInOnMap =
      list.where((s) => (s['gps_check_in'] as Map?)?['lat'] != null).length;
  final resolved = completed + missed + cancelled;
  final completionRate = resolved > 0 ? (completed * 100 ~/ resolved) : 0;
  final missedRate = resolved > 0 ? (missed * 100 ~/ resolved) : 0;
  final activeCaregivers = list
      .where((s) => s['status'] == 'checked_in')
      .map((s) => s['caregiver'])
      .toSet()
      .length;
  var durSum = 0, durCnt = 0;
  for (final s in list) {
    if (s['status'] == 'completed' &&
        s['check_in_at'] != null &&
        s['check_out_at'] != null) {
      final a = DateTime.tryParse(s['check_in_at'].toString());
      final b = DateTime.tryParse(s['check_out_at'].toString());
      if (a != null && b != null) {
        final ms = b.difference(a).inMilliseconds;
        if (ms > 0 && ms < 86400000) {
          durSum += ms;
          durCnt++;
        }
      }
    }
  }
  final avgDuration = durCnt > 0
      ? (durSum / durCnt / 3600000).toStringAsFixed(1)
      : '0';
  return _Kpis(
    total: total,
    inProgress: inProgress,
    completed: completed,
    missed: missed,
    cancelled: cancelled,
    checkedInOnMap: checkedInOnMap,
    completionRate: completionRate,
    missedRate: missedRate,
    activeCaregivers: activeCaregivers,
    avgDuration: avgDuration,
  );
}

List<({String label, num value, Color color})> _statusSegments(List<Map> list) {
  return [
    (label: 'Scheduled', value: list.where((s) => s['status'] == 'scheduled').length, color: _cmBlue),
    (label: 'In progress', value: list.where((s) => s['status'] == 'checked_in').length, color: _cmTeal),
    (label: 'Completed', value: list.where((s) => s['status'] == 'completed').length, color: _cmGreen),
    (label: 'Missed', value: list.where((s) => s['status'] == 'missed').length, color: _cmAmber),
    (label: 'Cancelled', value: list.where((s) => s['status'] == 'cancelled').length, color: _cmSlate),
  ].where((s) => s.value > 0).toList();
}

List<({String label, int value, int pct, IconData icon, Color color})>
    _shiftBars(List<Map> list) {
  final counts = <String, int>{};
  for (final s in list) {
    final t = s['shift_type']?.toString() ?? '';
    counts[t] = (counts[t] ?? 0) + 1;
  }
  final total = list.isEmpty ? 1 : list.length;
  return [
    ('Single Visit', 'visit', Icons.directions_walk_rounded, _cmTeal),
    ('Live-in', 'live_in', Icons.home_rounded, _cmIndigo),
    ('On Call', 'on_call', Icons.phone_in_talk_rounded, _cmPink),
  ].map((i) {
    final v = counts[i.$2] ?? 0;
    return (
      label: i.$1,
      value: v,
      pct: (v * 100 ~/ total),
      icon: i.$3,
      color: i.$4,
    );
  }).toList();
}

List<({String label, num value, Color color})> _punctualitySegments(List<Map> list) {
  final withCheck = list.where((s) => s['check_in_at'] != null && s['start_at'] != null);
  var onTime = 0, late = 0;
  const grace = 15 * 60000;
  for (final s in withCheck) {
    final a = DateTime.tryParse(s['check_in_at'].toString());
    final b = DateTime.tryParse(s['start_at'].toString());
    if (a != null && b != null) {
      if (a.difference(b).inMilliseconds <= grace) {
        onTime++;
      } else {
        late++;
      }
    }
  }
  return [
    (label: 'On time', value: onTime, color: _cmGreen),
    (label: 'Late', value: late, color: _cmAmber),
  ];
}

int _punctualityPct(List<({String label, num value, Color color})> segs) {
  final tot = segs.fold<int>(0, (a, b) => a + b.value.toInt());
  if (tot == 0) return 0;
  return (segs[0].value.toInt() * 100 ~/ tot);
}

List<_PerCaregiver> _perCaregiver(List<Map> list, List<Map> caregivers) {
  final byId = <int, _PerCaregiver>{};
  for (final s in list) {
    final id = s['caregiver'] as int?;
    if (id == null) continue;
    final cur = byId.putIfAbsent(
        id,
        () => _PerCaregiver(
            id: id,
            name: s['caregiver_name']?.toString(),
            category: (caregivers.cast<Map?>().firstWhere(
                    (c) => c?['id'] == id,
                    orElse: () => null))?['category']?.toString()));
    final e = _PerCaregiver(
      id: id,
      name: cur.name,
      category: cur.category,
      total: cur.total + 1,
      completed: cur.completed + (s['status'] == 'completed' ? 1 : 0),
      missed: cur.missed + (s['status'] == 'missed' ? 1 : 0),
      inProgress: cur.inProgress + (s['status'] == 'checked_in' ? 1 : 0),
      checkIns: cur.checkIns + (s['check_in_at'] != null ? 1 : 0),
      onTime: cur.onTime +
          ((s['check_in_at'] != null &&
                  s['start_at'] != null &&
                  (DateTime.tryParse(s['check_in_at'].toString())
                              ?.difference(DateTime.parse(s['start_at'].toString()))
                              .inMilliseconds ??
                          1) <=
                      15 * 60000)
              ? 1
              : 0),
      durSumMs: cur.durSumMs +
          ((s['status'] == 'completed' &&
                  s['check_in_at'] != null &&
                  s['check_out_at'] != null)
              ? (() {
                  final a = DateTime.tryParse(s['check_in_at'].toString());
                  final b = DateTime.tryParse(s['check_out_at'].toString());
                  if (a != null &&
                      b != null &&
                      b.difference(a).inMilliseconds > 0 &&
                      b.difference(a).inMilliseconds < 86400000) {
                    return b.difference(a).inMilliseconds;
                  }
                  return 0;
                }())
              : 0),
      durCnt: cur.durCnt +
          ((s['status'] == 'completed' &&
                  s['check_in_at'] != null &&
                  s['check_out_at'] != null)
              ? (() {
                  final a = DateTime.tryParse(s['check_in_at'].toString());
                  final b = DateTime.tryParse(s['check_out_at'].toString());
                  if (a != null &&
                      b != null &&
                      b.difference(a).inMilliseconds > 0 &&
                      b.difference(a).inMilliseconds < 86400000) {
                    return 1;
                  }
                  return 0;
                }())
              : 0),
    );
    byId[id] = e;
  }
  return byId.values.toList();
}

List<_PerCaregiver> _topCaregivers(List<_PerCaregiver> all) {
  final arr = List<_PerCaregiver>.from(all)
    ..sort((a, b) => b.total.compareTo(a.total));
  return arr.take(8).toList();
}

List<_DoseAgg> _perCaregiverDoses(List<Map> doses, List<Map> caregivers) {
  final byId = <int, _DoseAgg>{};
  final patientsById = <int, Set<int>>{};
  for (final d in doses) {
    final id = d['administered_by_caregiver'] as int?;
    if (id == null) continue;
    final meta = caregivers.cast<Map?>().firstWhere((c) => c?['id'] == id,
        orElse: () => null);
    final cur = byId.putIfAbsent(
        id,
        () => _DoseAgg(
            id: id,
            name: d['administered_by_name']?.toString(),
            category: meta?['category']?.toString()));
    int taken = cur.taken, missed = cur.missed, skipped = cur.skipped,
        notGiven = cur.notGiven, refused = cur.refused, pending = cur.pending;
    int autoMissed = cur.autoMissed, onTime = cur.onTime,
        takenWithTime = cur.takenWithTime;
    final st = d['status']?.toString();
    if (st == 'taken') {
      taken++;
      final aa = DateTime.tryParse(d['administered_at']?.toString() ?? '');
      final sa = DateTime.tryParse(d['scheduled_at']?.toString() ?? '');
      if (aa != null && sa != null) {
        takenWithTime++;
        if (aa.difference(sa).inMilliseconds <= 60 * 60000) onTime++;
      }
    }
    if (st == 'missed') missed++;
    if (st == 'skipped') skipped++;
    if (st == 'not_given') notGiven++;
    if (st == 'refused') refused++;
    if (st == 'pending') pending++;
    if (d['auto_missed'] == true) autoMissed++;
    final pid = d['patient_id'] as int?;
    if (pid != null) {
      patientsById.putIfAbsent(id, () => {});
      patientsById[id]!.add(pid);
    }
    byId[id] = _DoseAgg(
      id: id,
      name: cur.name,
      category: cur.category,
      total: cur.total + 1,
      taken: taken,
      missed: missed,
      skipped: skipped,
      notGiven: notGiven,
      refused: refused,
      pending: pending,
      autoMissed: autoMissed,
      onTime: onTime,
      takenWithTime: takenWithTime,
      patients: patientsById[id]?.length ?? cur.patients,
      finalized: 0,
      adherenceRate: 0,
      onTimeRate: 0,
    );
  }
  // finalize computed fields
  return byId.values.map((e) {
    final fin = e.taken + e.missed + e.skipped + e.notGiven + e.refused;
    final adh = fin > 0 ? (e.taken * 100 ~/ fin) : 0;
    final otr = e.takenWithTime > 0 ? (e.onTime * 100 ~/ e.takenWithTime) : 0;
    return _DoseAgg(
      id: e.id,
      name: e.name,
      category: e.category,
      total: e.total,
      taken: e.taken,
      missed: e.missed,
      skipped: e.skipped,
      notGiven: e.notGiven,
      refused: e.refused,
      pending: e.pending,
      autoMissed: e.autoMissed,
      onTime: e.onTime,
      takenWithTime: e.takenWithTime,
      patients: e.patients,
      finalized: fin,
      adherenceRate: adh,
      onTimeRate: otr,
    );
  }).toList();
}

_DoseKpis _doseKpis(List<Map> doses) {
  var taken = 0, missed = 0, skipped = 0, refused = 0, notGiven = 0,
      pending = 0, autoMissed = 0, administered = 0;
  for (final d in doses) {
    final st = d['status']?.toString();
    if (st == 'taken') taken++;
    if (st == 'missed') missed++;
    if (st == 'skipped') skipped++;
    if (st == 'refused') refused++;
    if (st == 'not_given') notGiven++;
    if (st == 'pending') pending++;
    if (d['auto_missed'] == true) autoMissed++;
    if (d['administered_by_caregiver'] != null) administered++;
  }
  final finalized = taken + missed + skipped + refused + notGiven;
  final adh = finalized > 0 ? (taken * 100 ~/ finalized) : 0;
  return _DoseKpis(
    total: doses.length,
    taken: taken,
    missed: missed,
    skipped: skipped,
    refused: refused,
    notGiven: notGiven,
    pending: pending,
    autoMissed: autoMissed,
    administered: administered,
    finalized: finalized,
    adherenceRate: adh,
  );
}

List<({String label, num value, Color color})> _doseStatusSegments(_DoseKpis c) {
  return [
    (label: 'Documented', value: c.taken, color: _cmGreenDeep),
    (label: 'Missed', value: c.missed, color: _cmRed),
    (label: 'Skipped', value: c.skipped, color: _cmSlate),
    (label: 'Refused', value: c.refused, color: _cmSlateDeep),
    (label: 'Not given', value: c.notGiven, color: _cmRed),
    (label: 'Pending', value: c.pending, color: _cmAmber),
  ].where((s) => s.value > 0).toList();
}

// ═══════════════════════════════════════════════════════════════════
//  Screen
// ═══════════════════════════════════════════════════════════════════
class HomecareCaregiverMonitorScreen extends ConsumerStatefulWidget {
  const HomecareCaregiverMonitorScreen({super.key});

  @override
  ConsumerState<HomecareCaregiverMonitorScreen> createState() =>
      _HomecareCaregiverMonitorScreenState();
}

class _HomecareCaregiverMonitorScreenState
    extends ConsumerState<HomecareCaregiverMonitorScreen> {
  String _range = '7d';
  DateTimeRange? _customRange;
  String? _statusFilter;
  int? _caregiverFilter;
  String _search = '';
  int? _selectedCaregiver;
  final GlobalKey _mapKey = GlobalKey();
  Timer? _liveTimer;
  bool _live = false;

  _MonitorKey get _key => _MonitorKey(
        _range,
        _range == 'custom' && _customRange != null
            ? '${_customRange!.start.year}-${_customRange!.start.month.toString().padLeft(2, '0')}-${_customRange!.start.day.toString().padLeft(2, '0')}'
            : null,
        _range == 'custom' && _customRange != null
            ? '${_customRange!.end.year}-${_customRange!.end.month.toString().padLeft(2, '0')}-${_customRange!.end.day.toString().padLeft(2, '0')}'
            : null,
      );

  void _reload() => ref.invalidate(_monitorProvider(_key));

  void _toggleLive() {
    if (_live) {
      _liveTimer?.cancel();
      _liveTimer = null;
      setState(() => _live = false);
    } else {
      setState(() => _live = true);
      _liveTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (mounted) ref.invalidate(_monitorProvider(_key));
      });
    }
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  void _focusMap() {
    final ctx = _mapKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          alignment: 0.0);
    }
  }

  void _openDetail(Map s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _ScheduleDetailSheet(
        schedule: s,
        onShowMap: (s['gps_check_in'] as Map?)?['lat'] != null
            ? () {
                Navigator.pop(context);
                _focusMap();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_monitorProvider(_key));
    final cs = Theme.of(context).colorScheme;

    return HcAsyncBody(
      value: async,
      onRefresh: () async => ref.refresh(_monitorProvider(_key).future),
      builder: (data) {
        final caregivers = data.caregivers;
        final schedules = data.schedules;
        final doses = data.doses;

        final filtered = _filterSchedules(
            schedules, _statusFilter, _caregiverFilter, _search);
        final kpis = _computeKpis(filtered);
        final statusSegs = _statusSegments(filtered);
        final shiftBars = _shiftBars(filtered);
        final punctSegs = _punctualitySegments(filtered);
        final punctPct = _punctualityPct(punctSegs);
        final perCaregiver = _perCaregiver(filtered, caregivers);
        final top = _topCaregivers(perCaregiver);
        final topMax = top.isEmpty ? 1 : top.first.total;
        final checkIns = filtered
            .where((s) => s['check_in_at'] != null)
            .toList()
          ..sort((a, b) => DateTime.parse(b['check_in_at'].toString())
              .compareTo(DateTime.parse(a['check_in_at'].toString())));
        final checkInList = checkIns.take(50).toList();
        final doseKpis = _doseKpis(doses);
        final doseSegs = _doseStatusSegments(doseKpis);
        final perCaregiverDoses = _perCaregiverDoses(doses, caregivers);
        final doseRanking = List<_DoseAgg>.from(perCaregiverDoses)
          ..sort((a, b) => b.adherenceRate != a.adherenceRate
              ? b.adherenceRate.compareTo(a.adherenceRate)
              : b.taken.compareTo(a.taken));

        final selStats = perCaregiver
            .where((c) => c.id == _selectedCaregiver)
            .cast<_PerCaregiver?>()
            .firstWhere((c) => c != null, orElse: () => null);
        final selDose = perCaregiverDoses
            .where((d) => d.id == _selectedCaregiver)
            .cast<_DoseAgg?>()
            .firstWhere((d) => d != null, orElse: () => null);
        final selMeta = caregivers.cast<Map?>().firstWhere(
            (c) => c?['id'] == _selectedCaregiver,
            orElse: () => null);

        return ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            // ── Hero ──
            HcHero(
              eyebrow: 'ADMIN & MANAGEMENT · MONITOR',
              title: 'Caregiver Monitor',
              subtitle:
                  'Real-time command centre for caregiver schedules, check-ins and field locations.',
              icon: Icons.monitor_heart_rounded,
              gradient: const [_cmIndigo, _cmTeal, _cmTeal],
              chips: [
                HcHeroChip(
                    icon: Icons.calendar_month_rounded,
                    label: '${kpis.total} schedules'),
                HcHeroChip(
                    icon: Icons.update_rounded,
                    label: '${kpis.inProgress} in progress'),
                HcHeroChip(
                    icon: Icons.check_circle_rounded,
                    label: '${kpis.completed} completed'),
                HcHeroChip(
                    icon: Icons.location_on_rounded,
                    label: '${kpis.checkedInOnMap} on map'),
                HcHeroChip(
                    icon: Icons.warning_amber_rounded,
                    label: '${kpis.missed} missed'),
              ],
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _toggleLive,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _live
                            ? _cmGreenDeep.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (_live)
                          _PulseDot(color: Colors.white)
                        else
                          Icon(Icons.circle, size: 10, color: Colors.white70),
                        const SizedBox(width: 5),
                        Text(_live ? 'LIVE' : 'OFFLINE',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 6),
                  IconButton(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    color: Colors.white,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      shape: const CircleBorder(),
                    ),
                    iconSize: 18,
                  ),
                ],
              ),
            ),

            // ── Filter bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Row(children: [
                      HcRangeSelector(
                        value: _range,
                        customRange: _customRange,
                        onChanged: (v) => setState(() => _range = v),
                        onCustomRange: (r) => setState(() => _customRange = r),
                      ),
                      const Spacer(),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _search = v),
                          style: const TextStyle(fontSize: 12.5),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search caregiver, patient…',
                            hintStyle: const TextStyle(fontSize: 11),
                            prefixIcon:
                                const Icon(Icons.search_rounded, size: 18),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    width: 0.5, color: cs.outlineVariant)),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _statusFilter,
                          isDense: true,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Status',
                            hintStyle: const TextStyle(fontSize: 11),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    width: 0.5, color: cs.outlineVariant)),
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('All statuses',
                                    style: TextStyle(fontSize: 12))),
                            ..._statusMeta.entries.map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value.label,
                                    style: const TextStyle(fontSize: 12)))),
                          ],
                          onChanged: (v) =>
                              setState(() => _statusFilter = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: _caregiverFilter,
                          isDense: true,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Caregiver',
                            hintStyle: const TextStyle(fontSize: 11),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    width: 0.5, color: cs.outlineVariant)),
                          ),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text('All caregivers',
                                    style: TextStyle(fontSize: 12))),
                            ...caregivers.map((c) => DropdownMenuItem(
                                value: c['id'] as int,
                                child: Text(
                                    (c['user']?['full_name'] ??
                                            c['user']?['email'] ??
                                            'Caregiver')
                                        .toString(),
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (v) =>
                              setState(() => _caregiverFilter = v),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),

            // ── KPI strip ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  HcKpi(
                      label: 'Schedules',
                      value: '${kpis.total}',
                      icon: Icons.calendar_month_rounded,
                      color: _cmIndigo),
                  HcKpi(
                      label: 'In Progress',
                      value: '${kpis.inProgress}',
                      icon: Icons.update_rounded,
                      color: _cmSky,
                      hint: '${kpis.activeCaregivers} active caregivers'),
                  HcKpi(
                      label: 'Completed',
                      value: '${kpis.completed}',
                      icon: Icons.check_circle_rounded,
                      color: _cmGreenDeep,
                      hint: '${kpis.completionRate}% rate'),
                  HcKpi(
                      label: 'Missed',
                      value: '${kpis.missed}',
                      icon: Icons.warning_amber_rounded,
                      color: _cmAmber,
                      hint: '${kpis.missedRate}% rate'),
                  HcKpi(
                      label: 'On Map',
                      value: '${kpis.checkedInOnMap}',
                      icon: Icons.location_on_rounded,
                      color: _cmPurple,
                      hint: 'checked-in locations'),
                  HcKpi(
                      label: 'Avg Visit',
                      value: '${kpis.avgDuration}h',
                      icon: Icons.timer_outlined,
                      color: _cmPink,
                      hint: 'completed duration'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Caregiver schedules list ──
            HcPanel(
              title: 'Caregiver schedules',
              subtitle: 'All assignments with live status',
              icon: Icons.format_list_bulleted_rounded,
              color: _cmIndigo,
              action: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _cmIndigo.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(7)),
                child: Text('${filtered.length}',
                    style: TextStyle(
                        color: _cmIndigo,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              child: filtered.isEmpty
                  ? HcEmptyState(
                      icon: Icons.event_busy_rounded,
                      title: 'No schedules found',
                      message: 'Adjust the date range or filters.')
                  : Column(
                      children: [
                        for (final s in filtered.take(40))
                          _ScheduleTile(
                            schedule: s,
                            onTap: () => _openDetail(s),
                            onMap: (s['gps_check_in'] as Map?)?['lat'] != null
                                ? _focusMap
                                : null,
                          ),
                        if (filtered.length > 40)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Center(
                              child: Text(
                                  'Showing 40 of ${filtered.length} · refine filters to narrow',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurfaceVariant)),
                            ),
                          ),
                      ],
                    ),
            ),

            // ── Individual analysis ──
            HcPanel(
              title: 'Individual analysis',
              subtitle: 'Pick a caregiver to drill down',
              icon: Icons.person_search_rounded,
              color: _cmSky,
              child: Column(children: [
                DropdownButtonFormField<int?>(
                  value: _selectedCaregiver,
                  isDense: true,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Select caregiver',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.favorite_rounded,
                        size: 18, color: _cmSky),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            width: 0.5, color: cs.outlineVariant)),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('None',
                            style: TextStyle(fontSize: 12))),
                    ...caregivers.map((c) => DropdownMenuItem(
                        value: c['id'] as int,
                        child: Text(
                            (c['user']?['full_name'] ??
                                    c['user']?['email'] ??
                                    'Caregiver')
                                .toString(),
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setState(() => _selectedCaregiver = v),
                ),
                if (_selectedCaregiver != null) ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    HcAvatar(
                      name: selStats?.name ??
                          selMeta?['user']?['full_name'],
                      color: _catColor(selStats?.category ??
                          selMeta?['category']),
                      size: 46,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                selStats?.name ??
                                    selMeta?['user']?['full_name'] ??
                                    'Caregiver',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            HcStatusChip(
                              label: _catLabel(selStats?.category ??
                                  selMeta?['category']),
                              color: _catColor(selStats?.category ??
                                  selMeta?['category']),
                            ),
                          ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: _StatTile(
                            value: '${selStats?.total ?? 0}',
                            label: 'Schedules',
                            color: _cmIndigo)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _StatTile(
                            value: '${selStats?.completed ?? 0}',
                            label: 'Completed',
                            color: _cmGreenDeep)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: _StatTile(
                            value: '${selStats?.inProgress ?? 0}',
                            label: 'In progress',
                            color: _cmTeal)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _StatTile(
                            value: '${selStats?.missed ?? 0}',
                            label: 'Missed',
                            color: _cmAmber)),
                  ]),
                  const SizedBox(height: 14),
                  if (selStats != null)
                    _LabeledBar(
                      label: 'Completion rate',
                      value:
                          '${selStats.completed + selStats.missed > 0 ? (selStats.completed * 100 ~/ (selStats.completed + selStats.missed)) : 0}%',
                      pct: selStats.completed + selStats.missed > 0
                          ? (selStats.completed * 100 ~/
                              (selStats.completed + selStats.missed))
                          : 0,
                      color: _cmGreenDeep,
                    ),
                  const SizedBox(height: 8),
                  if (selStats != null)
                    _LabeledBar(
                      label: 'Avg visit duration',
                      value:
                          '${selStats.avgDurationHours.toStringAsFixed(1)}h',
                      pct: (selStats.avgDurationHours / 8 * 100)
                          .clamp(0, 100)
                          .toInt(),
                      color: _cmPink,
                    ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    HcStatusChip(
                      label: '${selStats?.checkIns ?? 0} check-ins',
                      color: _cmPurple,
                      icon: Icons.location_on_rounded,
                    ),
                    HcStatusChip(
                      label: '${selStats?.onTime ?? 0} on time',
                      color: _cmSky,
                      icon: Icons.timer_outlined,
                    ),
                  ]),
                  if (selDose != null) ...[
                    const Divider(height: 22),
                    Row(children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: Stack(alignment: Alignment.center, children: [
                          CircularProgressIndicator(
                            value: selDose.adherenceRate / 100,
                            strokeWidth: 6,
                            color:
                                _adherenceColor(selDose.adherenceRate),
                          ),
                          Text('${selDose.adherenceRate}%',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800)),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('DOSE ADHERENCE',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurfaceVariant,
                                      letterSpacing: 0.4)),
                              const SizedBox(height: 2),
                              Text(
                                  '${selDose.taken} taken · ${selDose.missed} missed',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  '${selDose.total} doses · ${selDose.patients} patients · ${selDose.onTimeRate}% on-time',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurfaceVariant)),
                            ]),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: selDose.adherenceRate / 100,
                        minHeight: 6,
                        color: _adherenceColor(selDose.adherenceRate),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () =>
                          context.go('/homecare/caregivers/$_selectedCaregiver'),
                      icon: const Icon(Icons.account_circle_rounded, size: 18),
                      label: const Text('View full profile',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                          backgroundColor: _cmIndigo.withValues(alpha: 0.12),
                          foregroundColor: _cmIndigo,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ] else
                  HcEmptyState(
                      icon: Icons.person_search_rounded,
                      title: 'Select a caregiver'),
              ]),
            ),

            // ── Check-ins & locations ──
            HcPanel(
              title: 'Check-ins & locations',
              subtitle: 'Live field check-ins with GPS',
              icon: Icons.location_on_rounded,
              color: _cmGreenDeep,
              action: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _cmGreenDeep.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(7)),
                child: Text('${checkInList.length}',
                    style: TextStyle(
                        color: _cmGreenDeep,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              child: checkInList.isEmpty
                  ? HcEmptyState(
                      icon: Icons.location_off_rounded,
                      title: 'No check-ins yet',
                      message: 'Checked-in caregivers will appear here.')
                  : SizedBox(
                      height: 380,
                      child: ListView.separated(
                        itemCount: checkInList.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final c = checkInList[i];
                          final hasGps =
                              (c['gps_check_in'] as Map?)?['lat'] != null;
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: hasGps ? _focusMap : null,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: c['status'] == 'checked_in'
                                        ? _cmTeal
                                        : cs.outlineVariant
                                            .withValues(alpha: 0.4),
                                    width:
                                        c['status'] == 'checked_in' ? 1.6 : 0.8),
                                color: c['status'] == 'checked_in'
                                    ? _cmTeal.withValues(alpha: 0.06)
                                    : Colors.transparent,
                              ),
                              child: Row(children: [
                                HcAvatar(
                                  name: c['caregiver_name']?.toString(),
                                  color: _catColor(c['caregiver_category']),
                                  size: 36,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            c['caregiver_name']?.toString() ??
                                                '—',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        Text(
                                            c['patient_name']?.toString() ??
                                                '—',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: cs.onSurfaceVariant),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          HcStatusChip(
                                            label: _sm(c['status']).label,
                                            color: _sm(c['status']).color,
                                            icon: _sm(c['status']).icon,
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(Icons.schedule_rounded,
                                              size: 11,
                                              color: cs.onSurfaceVariant),
                                          const SizedBox(width: 2),
                                          Text(_fmtTime(c['check_in_at']),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: cs.onSurfaceVariant)),
                                        ]),
                                      ]),
                                ),
                                if (hasGps)
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_on_rounded,
                                          color: _cmTeal, size: 18),
                                      Text(_gpsShort(c['gps_check_in']),
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: cs.onSurfaceVariant)),
                                    ],
                                  ),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
            ),

            // ── Status breakdown donut ──
            HcPanel(
              title: 'Status breakdown',
              icon: Icons.donut_large_rounded,
              color: _cmIndigo,
              child: statusSegs.isEmpty
                  ? HcEmptyState(icon: Icons.donut_small_outlined, title: 'No data')
                  : Column(children: [
                      Center(
                        child: HcDonutRing(
                          segments: statusSegs,
                          size: 160,
                          centerValue: '${kpis.total}',
                          centerLabel: 'visits',
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final s in statusSegs)
                        HcLegendRow(
                            label: s.label, value: s.value, color: s.color),
                    ]),
            ),

            // ── Shift mix ──
            HcPanel(
              title: 'Shift mix',
              subtitle: 'By assignment type',
              icon: Icons.work_history_rounded,
              color: _cmSky,
              child: Column(children: [
                for (final s in shiftBars)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Icon(s.icon, color: s.color, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(s.label,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: cs.onSurfaceVariant))),
                      Text('${s.value}',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                              value: (s.pct / 100).clamp(0, 1),
                              minHeight: 6,
                              color: s.color),
                        ),
                      ),
                    ]),
                  ),
                const Divider(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Completion performance',
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant)),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Stack(alignment: Alignment.center, children: [
                      CircularProgressIndicator(
                        value: kpis.completionRate / 100,
                        strokeWidth: 6,
                        color: _cmGreenDeep,
                      ),
                      Text('${kpis.completionRate}%',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${kpis.completed} completed',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                              'of ${kpis.completed + kpis.missed + kpis.cancelled} resolved',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurfaceVariant)),
                        ]),
                  ),
                ]),
              ]),
            ),

            // ── Punctuality donut ──
            HcPanel(
              title: 'Punctuality',
              subtitle: 'On-time vs late check-ins',
              icon: Icons.timer_outlined,
              color: _cmGreenDeep,
              child: Column(children: [
                Center(
                  child: HcDonutRing(
                    segments: punctSegs,
                    size: 150,
                    centerValue: '$punctPct%',
                    centerLabel: 'on time',
                  ),
                ),
                const SizedBox(height: 8),
                for (final p in punctSegs)
                  HcLegendRow(
                      label: p.label, value: p.value, color: p.color),
              ]),
            ),

            // ── Busiest caregivers ──
            HcPanel(
              title: 'Busiest caregivers',
              subtitle: 'Most assignments in range',
              icon: Icons.emoji_events_rounded,
              color: _cmAmber,
              child: top.isEmpty
                  ? HcEmptyState(icon: Icons.emoji_events_outlined, title: 'No data')
                  : Column(
                      children: [
                        for (var i = 0; i < top.length; i++)
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(
                                () => _selectedCaregiver = top[i].id),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 5),
                              child: Row(children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                      color: _leaderColors[i %
                                              _leaderColors.length]
                                          .withValues(alpha: 0.14),
                                      shape: BoxShape.circle),
                                  alignment: Alignment.center,
                                  child: Text('${i + 1}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: _leaderColors[
                                              i % _leaderColors.length])),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            top[i].name ?? 'Caregiver',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        Text(
                                            '${top[i].total} visits · ${top[i].completed} done',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: cs.onSurfaceVariant)),
                                      ]),
                                ),
                                SizedBox(
                                  width: 60,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                        value: (top[i].total / topMax)
                                            .clamp(0, 1)
                                            .toDouble(),
                                        minHeight: 6,
                                        color: _cmAmber),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text('${top[i].total}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800)),
                              ]),
                            ),
                          ),
                      ],
                    ),
            ),

            // ── Assignments per caregiver bar chart ──
            HcPanel(
              title: 'Assignments per caregiver',
              subtitle: 'Workload distribution in selected range',
              icon: Icons.bar_chart_rounded,
              color: _cmPurple,
              child: perCaregiver.isEmpty
                  ? HcEmptyState(icon: Icons.bar_chart_rounded, title: 'No assignments')
                  : Builder(builder: (_) {
                      final arr = List<_PerCaregiver>.from(perCaregiver)
                        ..sort((a, b) => b.total.compareTo(a.total));
                      final top12 = arr.take(12).toList();
                      return HcBarChart(
                        height: 240,
                        groups: top12.map((c) => [c.total]).toList(),
                        labels: top12
                            .map((c) => (c.name ?? '—')
                                .split(' ')
                                .first)
                            .toList(),
                        colors: top12
                            .map((c) => _catColor(c.category))
                            .toList(),
                        scrollable: top12.length > 6,
                      );
                    }),
            ),

            // ── Status trend bar chart ──
            HcPanel(
              title: 'Status trend',
              subtitle: 'Schedules grouped by day',
              icon: Icons.show_chart_rounded,
              color: _cmPink,
              child: Builder(builder: (_) {
                final byDay = <String, int>{};
                for (final s in filtered) {
                  final d =
                      DateTime.tryParse(s['start_at']?.toString() ?? '');
                  if (d == null) continue;
                  final key =
                      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                  byDay[key] = (byDay[key] ?? 0) + 1;
                }
                final keys = byDay.keys.toList()..sort();
                if (keys.isEmpty) {
                  return HcEmptyState(
                      icon: Icons.show_chart_rounded, title: 'No trend data');
                }
                return HcBarChart(
                  height: 240,
                  groups: keys.map((k) => [byDay[k]!]).toList(),
                  labels: keys.map((k) => k.substring(5)).toList(),
                  colors: keys.map((_) => _cmPink).toList(),
                  scrollable: keys.length > 6,
                );
              }),
            ),

            // ── Caregiver dose adherence ranking ──
            HcPanel(
              title: 'Caregiver dose adherence',
              subtitle:
                  'How well each caregiver ensures patients take prescribed doses',
              icon: Icons.medication_rounded,
              color: _cmGreenDeep,
              action: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _cmGreenDeep.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(7)),
                child: Text('${doseRanking.length} caregivers',
                    style: TextStyle(
                        color: _cmGreenDeep,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              child: doseRanking.isEmpty
                  ? HcEmptyState(
                      icon: Icons.medication_liquid_rounded,
                      title: 'No dose data',
                      message:
                          'Documented doses will appear here for the selected range.')
                  : SizedBox(
                      height: 460,
                      child: ListView.separated(
                        itemCount: doseRanking.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final c = doseRanking[i];
                          final selected = c.id == _selectedCaregiver;
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () =>
                                setState(() => _selectedCaregiver = c.id),
                            child: AnimatedContainer(
                              duration:
                                  const Duration(milliseconds: 120),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: selected
                                        ? _cmGreenDeep
                                        : cs.outlineVariant
                                            .withValues(alpha: 0.4),
                                    width: selected ? 1.6 : 0.8),
                                color: selected
                                    ? _cmGreenDeep.withValues(alpha: 0.08)
                                    : Colors.transparent,
                              ),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      HcAvatar(
                                        name: c.name,
                                        color: _catColor(c.category),
                                        size: 34,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(c.name ?? 'Caregiver',
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700),
                                                  maxLines: 1,
                                                  overflow: TextOverflow
                                                      .ellipsis),
                                              Text(
                                                  '${c.taken} taken · ${c.missed} missed · ${c.skipped + c.refused + c.notGiven} other · ${c.patients} patients',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: cs
                                                          .onSurfaceVariant),
                                                  maxLines: 1,
                                                  overflow: TextOverflow
                                                      .ellipsis),
                                            ]),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text('${c.adherenceRate}%',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                      FontWeight.w800,
                                                  color:
                                                      _adherenceColor(
                                                          c.adherenceRate))),
                                          Text('adherence',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: cs
                                                      .onSurfaceVariant)),
                                        ],
                                      ),
                                    ]),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: c.adherenceRate / 100,
                                        minHeight: 7,
                                        color: _adherenceColor(
                                            c.adherenceRate),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                        children: [
                                          Text(
                                              'on-time docs ${c.onTimeRate}% · ${c.total} doses',
                                              style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: cs
                                                      .onSurfaceVariant)),
                                          if (c.autoMissed > 0)
                                            Text(
                                                '${c.autoMissed} auto-missed',
                                                style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: _cmAmber))
                                          else
                                            Text(
                                                '${c.finalized} finalized',
                                                style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color:
                                                        _adherenceColor(
                                                            c.adherenceRate))),
                                        ]),
                                  ]),
                            ),
                          );
                        },
                      ),
                    ),
            ),

            // ── Adherence overview ──
            HcPanel(
              title: 'Adherence overview',
              subtitle: 'All doses in selected range',
              icon: Icons.monitor_heart_rounded,
              color: _cmRed,
              child: Column(children: [
                Row(children: [
                  SizedBox(
                    width: 84,
                    height: 84,
                    child: Stack(alignment: Alignment.center, children: [
                      CircularProgressIndicator(
                        value: doseKpis.adherenceRate / 100,
                        strokeWidth: 8,
                        color: _adherenceColor(doseKpis.adherenceRate),
                      ),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('${doseKpis.adherenceRate}%',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        Text('adherence',
                            style: TextStyle(
                                fontSize: 10,
                                color: cs.onSurfaceVariant)),
                      ]),
                    ]),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(children: [
                      _doseRow('Total doses', '${doseKpis.total}',
                          Icons.medication_rounded, _cmIndigo),
                      _doseRow('Documented', '${doseKpis.taken}',
                          Icons.check_circle_rounded, _cmGreenDeep),
                      _doseRow('Missed', '${doseKpis.missed}',
                          Icons.warning_amber_rounded, _cmRed),
                      _doseRow('By caregiver', '${doseKpis.administered}',
                          Icons.favorite_rounded, _cmTeal),
                    ]),
                  ),
                ]),
                const Divider(height: 24),
                Center(
                  child: HcDonutRing(
                    segments: doseSegs,
                    size: 150,
                    centerValue: '${doseKpis.finalized}',
                    centerLabel: 'finalized',
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in doseSegs)
                      HcStatusChip(
                          label: '${s.label} · ${s.value}', color: s.color),
                  ],
                ),
                if (doseKpis.autoMissed > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: _cmAmber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _cmAmber.withValues(alpha: 0.3))),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded,
                          color: _cmAmber, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            '${doseKpis.autoMissed} doses auto-marked missed (overdue)',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ]),
                  ),
                ],
              ]),
            ),

            // ── Live check-in map ──
            HcPanel(
              title: 'Live check-in map',
              subtitle: 'Real-time location of all checked-in caregivers',
              icon: Icons.map_rounded,
              color: hcTeal,
              action: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: hcTeal.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(7)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.location_on_rounded,
                      size: 13, color: hcTeal),
                  const SizedBox(width: 4),
                  Text(
                      '${filtered.where((s) => (s['gps_check_in'] as Map?)?['lat'] != null).length}',
                      style: const TextStyle(
                          color: hcTeal,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
              child: _MonitorMap(
                key: _mapKey,
                schedules: filtered,
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _doseRow(String label, String value, IconData icon, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant))),
        Text(value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Schedule detail bottom sheet (mirrors web detail dialog).
// ═══════════════════════════════════════════════════════════════════
class _ScheduleDetailSheet extends StatelessWidget {
  final Map schedule;
  final VoidCallback? onShowMap;
  const _ScheduleDetailSheet({required this.schedule, this.onShowMap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = schedule;
    final meta = _sm(s['status']);
    final g = s['gps_check_in'] as Map?;
    final hasGps = g?['lat'] != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: cs.outlineVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: meta.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(children: [
            Icon(meta.icon, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${meta.label} · ${_shiftLabel(s['shift_type'])}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(
                        '${_fmtDateTime(s['start_at'])} – ${_fmtTime(s['end_at'])}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        HcInfoRow(
            label: 'Caregiver',
            value: s['caregiver_name']?.toString() ?? '—',
            icon: Icons.medical_services_rounded),
        HcInfoRow(
            label: 'Patient',
            value: s['patient_name']?.toString() ?? '—',
            icon: Icons.person_rounded),
        if (s['check_in_at'] != null) ...[
          HcInfoRow(
              label: 'Checked in',
              value: _fmtDateTime(s['check_in_at']),
              icon: Icons.login_rounded),
          if (hasGps)
            Padding(
              padding: const EdgeInsets.only(left: 126, bottom: 4),
              child: Row(children: [
                Icon(Icons.location_on_rounded, size: 12, color: _cmTeal),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${(g!['lat'] as num).toStringAsFixed(4)}, ${(g['lng'] as num).toStringAsFixed(4)}  ±${((g['accuracy'] as num?) ?? 0).round()}m',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  )),
              ]),
            ),
        ],
        if (s['check_out_at'] != null) ...[
          HcInfoRow(
              label: 'Checked out',
              value: _fmtDateTime(s['check_out_at']),
              icon: Icons.logout_rounded),
          if (s['check_in_at'] != null)
            HcInfoRow(
                label: 'Duration',
                value: _duration(s['check_in_at'], s['check_out_at']),
                icon: Icons.timer_outlined),
        ],
        if (s['notes'] != null && s['notes'].toString().isNotEmpty) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Notes',
                style:
                    TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10)),
            child: Text(s['notes'].toString(),
                style: const TextStyle(fontSize: 12.5)),
          ),
        ],
        const SizedBox(height: 18),
        Row(children: [
          if (hasGps && onShowMap != null)
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onShowMap,
                icon: const Icon(Icons.location_on_rounded, size: 18),
                label: const Text('Show on map',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                style: FilledButton.styleFrom(
                    backgroundColor: _cmTeal.withValues(alpha: 0.12),
                    foregroundColor: _cmTeal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
          if (hasGps && onShowMap != null) const SizedBox(width: 8),
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Supporting widgets
// ═══════════════════════════════════════════════════════════════════

/// Pulsing dot used in the LIVE chip.
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with TickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _a = Tween(begin: 1.0, end: 0.25).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: Icon(Icons.circle, size: 10, color: widget.color),
    );
  }
}

/// A single schedule row tile.
class _ScheduleTile extends StatelessWidget {
  final Map schedule;
  final VoidCallback onTap;
  final VoidCallback? onMap;
  const _ScheduleTile(
      {required this.schedule, required this.onTap, this.onMap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = schedule;
    final meta = _sm(s['status']);
    final hasGps = (s['gps_check_in'] as Map?)?['lat'] != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            HcAvatar(
              name: s['caregiver_name']?.toString(),
              color: _catColor(s['caregiver_category']),
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s['caregiver_name']?.toString() ?? '—',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(s['patient_name']?.toString() ?? '—',
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      HcStatusChip(
                          label: meta.label, color: meta.color, icon: meta.icon),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                            '${_fmtDateTime(s['start_at'])} → ${_fmtTime(s['end_at'])} · ${_shiftLabel(s['shift_type'])}',
                            style: TextStyle(
                                fontSize: 10.5,
                                color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ]),
            ),
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (s['check_in_at'] != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.location_on_rounded,
                        size: 14,
                        color: hasGps ? _cmTeal : cs.onSurfaceVariant),
                    const SizedBox(width: 2),
                    Text(_fmtTime(s['check_in_at']),
                        style: TextStyle(
                            fontSize: 11, color: cs.onSurfaceVariant)),
                  ])
                else
                  Text('—',
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onTap,
                    icon: const Icon(Icons.visibility_outlined),
                    color: _cmIndigo,
                  ),
                  if (hasGps)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onMap,
                      icon: const Icon(Icons.location_on_rounded),
                      color: _cmTeal,
                    ),
                ]),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

/// Stat tile used inside individual analysis.
class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatTile(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color)),
        const SizedBox(height: 2),
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

/// Labelled progress bar (label — value — bar).
class _LabeledBar extends StatelessWidget {
  final String label;
  final String value;
  final int pct;
  final Color color;
  const _LabeledBar(
      {required this.label,
      required this.value,
      required this.pct,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurfaceVariant)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (pct / 100).clamp(0, 1),
            minHeight: 8,
            borderRadius: BorderRadius.circular(6),
            color: color,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Live check-in Google Map with bouncing live markers, info
//  windows and auto-fit bounds (mirrors web CaregiverMonitorMap).
// ═══════════════════════════════════════════════════════════════════
class _MonitorMap extends StatefulWidget {
  final List<Map> schedules;
  const _MonitorMap({super.key, required this.schedules});

  @override
  State<_MonitorMap> createState() => _MonitorMapState();
}

class _MonitorMapState extends State<_MonitorMap> {
  GoogleMapController? _ctrl;
  Set<Marker> _markers = {};
  bool _loading = true;

  static const _default = LatLng(-1.2921, 36.8219); // Nairobi

  double _hueFor(String? status) => switch (status) {
        'checked_in' => BitmapDescriptor.hueCyan,
        'completed' => BitmapDescriptor.hueGreen,
        'scheduled' => BitmapDescriptor.hueAzure,
        'missed' => BitmapDescriptor.hueOrange,
        'cancelled' => BitmapDescriptor.hueViolet,
        _ => BitmapDescriptor.hueRose,
      };

  void _buildMarkers() {
    final ms = <Marker>{};
    for (final s in widget.schedules) {
      final g = s['gps_check_in'] as Map?;
      final lat = (g?['lat'] as num?)?.toDouble();
      final lng = (g?['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final live = s['status'] == 'checked_in';
      ms.add(Marker(
        markerId: MarkerId('sch_${s['id']}'),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(_hueFor(s['status'])),
        zIndexInt: live ? 999 : 1,
        infoWindow: InfoWindow(
          title: s['caregiver_name']?.toString() ?? 'Caregiver',
          snippet:
              'Patient: ${s['patient_name'] ?? '—'} · ${_sm(s['status']).label} · ${_fmtDateTime(s['check_in_at'])}',
        ),
      ));
    }
    if (mounted) {
      setState(() {
        _markers = ms;
        _loading = false;
      });
    }
    _fitBounds();
  }

  void _fitBounds() {
    final geo = widget.schedules
        .where((s) => (s['gps_check_in'] as Map?)?['lat'] != null)
        .toList();
    if (geo.isEmpty || _ctrl == null) return;
    if (geo.length == 1) {
      final g = geo[0]['gps_check_in'] as Map;
      _ctrl!.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng((g['lat'] as num).toDouble(), (g['lng'] as num).toDouble()),
          15));
      return;
    }
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final s in geo) {
      final g = s['gps_check_in'] as Map;
      final lat = (g['lat'] as num).toDouble();
      final lng = (g['lng'] as num).toDouble();
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }
    _ctrl!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
          southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
      60,
    ));
  }

  @override
  void didUpdateWidget(covariant _MonitorMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schedules != widget.schedules) _buildMarkers();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasMarkers = _markers.isNotEmpty;
    return Column(children: [
      SizedBox(
        height: 420,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(children: [
            GoogleMap(
              initialCameraPosition:
                  const CameraPosition(target: _default, zoom: 12),
              onMapCreated: (c) {
                _ctrl = c;
                Future.delayed(const Duration(milliseconds: 300),
                    _buildMarkers);
              },
              markers: _markers,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              mapToolbarEnabled: false,
              compassEnabled: true,
            ),
            if (_loading)
              Container(
                color: Colors.black12,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            if (!hasMarkers && !_loading)
              Container(
                alignment: Alignment.center,
                color: cs.surface.withValues(alpha: 0.6),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_off_rounded,
                          size: 40, color: cs.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text('No checked-in locations',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant)),
                    ]),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 10,
        runSpacing: 6,
        children: [
          _mapLegend('Live', _cmTeal),
          _mapLegend('Completed', _cmGreen),
          _mapLegend('Scheduled', _cmBlue),
          _mapLegend('Missed', _cmAmber),
          _mapLegend('Cancelled', _cmSlate),
        ],
      ),
    ]);
  }

  Widget _mapLegend(String label, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.circle, size: 9, color: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11)),
    ]);
  }
}
