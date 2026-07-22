import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api.dart';
import '../../providers/auth_provider.dart';
import 'hc_common.dart';

// ═════════════════ Constants ═════════════════
const _statusMeta = {
  'scheduled':  {'label': 'Scheduled',  'icon': Icons.schedule_rounded,      'color': Color(0xFF2563EB)},
  'checked_in': {'label': 'In progress', 'icon': Icons.timelapse_rounded,     'color': Color(0xFF0D9488)},
  'completed':  {'label': 'Completed',  'icon': Icons.check_circle_rounded,   'color': Color(0xFF16A34A)},
  'missed':     {'label': 'Missed',     'icon': Icons.error_rounded,          'color': Color(0xFFF59E0B)},
  'cancelled':  {'label': 'Cancelled',  'icon': Icons.cancel_rounded,         'color': Color(0xFF64748B)},
};

const _statusOptions = ['scheduled', 'checked_in', 'completed', 'missed', 'cancelled'];

const _shiftTypeOptions = [
  {'value': 'visit',   'label': 'Single Visit'},
  {'value': 'live_in', 'label': 'Live-in'},
  {'value': 'on_call', 'label': 'On Call'},
];

const _recurrenceModes = [
  {'value': 'none',  'label': 'No repeat'},
  {'value': 'daily', 'label': 'Daily'},
  {'value': 'weekly','label': 'Weekly'},
];

const _weekdays = [
  {'value': 'MO', 'short': 'Mon'}, {'value': 'TU', 'short': 'Tue'},
  {'value': 'WE', 'short': 'Wed'}, {'value': 'TH', 'short': 'Thu'},
  {'value': 'FR', 'short': 'Fri'}, {'value': 'SA', 'short': 'Sat'},
  {'value': 'SU', 'short': 'Sun'},
];

String _shiftLabel(String? v) {
  for (final o in _shiftTypeOptions) {
    if (o['value'] == v) return o['label'] as String;
  }
  return v ?? '—';
}

Color _statusColor(String? s) => _statusMeta[s]?['color'] as Color? ?? hcSlate;
IconData _statusIcon(String? s) => _statusMeta[s]?['icon'] as IconData? ?? Icons.circle_rounded;
String _statusLabel(String? s) => _statusMeta[s]?['label'] as String? ?? (s ?? '—');

// ═════════════════ Providers ═════════════════
final _optionsProvider = FutureProvider.autoDispose((ref) async {
  final results = await Future.wait([
    hcFetchAll(ref, '/homecare/caregivers/', params: {'page_size': 500}),
    hcFetchAll(ref, '/homecare/patients/', params: {'is_active': 'true', 'page_size': 500}),
  ]);
  return {'caregivers': results[0], 'patients': results[1]};
});

/// Role-aware entry: caregivers get an isolated, read-only view of their own
/// shifts; admins/managers get the full scheduling screen.
class HomecareSchedulesEntry extends ConsumerWidget {
  const HomecareSchedulesEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCaregiver = ref.watch(authProvider).role == 'caregiver';
    return HomecareSchedulesScreen(caregiverOnly: isCaregiver);
  }
}

// ═════════════════ Screen ═════════════════
class HomecareSchedulesScreen extends ConsumerStatefulWidget {
  final bool caregiverOnly;
  const HomecareSchedulesScreen({super.key, this.caregiverOnly = false});

  @override
  ConsumerState<HomecareSchedulesScreen> createState() => _HomecareSchedulesScreenState();
}

class _HomecareSchedulesScreenState extends ConsumerState<HomecareSchedulesScreen> {
  String _view = 'day'; // day | week | list
  DateTime _cursor = DateTime.now();
  List<Map> _items = [];
  bool _loading = false;
  String _search = '';
  String _filterStatus = '';
  String _filterShiftType = '';
  int? _filterCaregiver;
  int? _filterPatient;
  int? _meCaregiverId;

  bool get _readOnly => widget.caregiverOnly;

  @override
  void initState() {
    super.initState();
    if (widget.caregiverOnly) {
      _loadMe();
    } else {
      _load();
    }
  }

  Future<void> _loadMe() async {
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/homecare/caregivers/me/');
      final d = res.data;
      _meCaregiverId = (d is Map ? d : null)?['id'] as int?;
    } catch (_) {
      _meCaregiverId = null;
    }
    _load();
  }

  // ── Date range ──
  DateTime get _rangeStart {
    if (_view == 'day') return DateTime(_cursor.year, _cursor.month, _cursor.day);
    if (_view == 'week') {
      final d = DateTime(_cursor.year, _cursor.month, _cursor.day);
      final day = (d.weekday - 1) % 7;
      return d.subtract(Duration(days: day));
    }
    // list = -7..+30
    return DateTime(_cursor.year, _cursor.month, _cursor.day).subtract(const Duration(days: 7));
  }

  DateTime get _rangeEnd {
    if (_view == 'day') return DateTime(_cursor.year, _cursor.month, _cursor.day, 23, 59, 59);
    if (_view == 'week') return _rangeStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return DateTime(_cursor.year, _cursor.month, _cursor.day).add(const Duration(days: 30, hours: 23, minutes: 59, seconds: 59));
  }

  String get _rangeLabel {
    final fmt = DateFormat('d MMM yyyy');
    if (_view == 'day') {
      return DateFormat('EEEE, d MMMM yyyy').format(_cursor);
    }
    if (_view == 'week') {
      return '${DateFormat('d MMM').format(_rangeStart)} – ${fmt.format(_rangeEnd)}';
    }
    return '';
  }

  // ── Load ──
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/homecare/schedules/', queryParameters: {
        'start_after': _rangeStart.toUtc().toIso8601String(),
        'end_before': _rangeEnd.toUtc().toIso8601String(),
        'page_size': 500,
        if (widget.caregiverOnly && _meCaregiverId != null)
          'caregiver': _meCaregiverId,
      });
      final data = res.data;
      _items = (data is List ? data : (data?['results'] as List?) ?? []).cast<Map>().toList();
    } catch (_) {
      _items = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigate(int delta) {
    if (_view == 'day') {
      _cursor = _cursor.add(Duration(days: delta));
    } else if (_view == 'week') {
      _cursor = _cursor.add(Duration(days: delta * 7));
    }
    _load();
  }

  void _goToday() {
    _cursor = DateTime.now();
    _load();
  }

  // ── Filters ──
  List<Map> get _filtered {
    return _items.where((ev) {
      if (widget.caregiverOnly && _meCaregiverId != null && ev['caregiver'] != _meCaregiverId) return false;
      if (_filterCaregiver != null && ev['caregiver'] != _filterCaregiver) return false;
      if (_filterPatient != null && ev['patient'] != _filterPatient) return false;
      if (_filterStatus.isNotEmpty && ev['status'] != _filterStatus) return false;
      if (_filterShiftType.isNotEmpty && ev['shift_type'] != _filterShiftType) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final blob = '${ev['caregiver_name']} ${ev['patient_name']} ${ev['notes']}'.toLowerCase();
        if (!blob.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  // ── KPIs ──
  Map<String, int> get _kpis {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
    int t = 0, ct = 0, ip = 0, up = 0, ms = 0;
    for (final ev in _items) {
      final s = DateTime.tryParse(ev['start_at']?.toString() ?? '')?.toLocal();
      if (s == null) continue;
      final onToday = !s.isBefore(todayStart) && !s.isAfter(todayEnd);
      if (onToday) t++;
      if (ev['status'] == 'checked_in') ip++;
      if (onToday && ev['status'] == 'completed') ct++;
      if (s.isAfter(today) && ev['status'] == 'scheduled') up++;
      if (ev['status'] == 'missed') ms++;
    }
    return {'today': t, 'completedToday': ct, 'inProgress': ip, 'upcoming': up, 'missed': ms};
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final kpis = _kpis;
    return Scaffold(
      body: Column(children: [
        Expanded(child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 90),
          children: [
            _buildHero(cs, kpis),
            _buildViewTabs(cs),
            _buildFilterBar(cs),
            if (_loading)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (_view == 'day')
              _buildDayView(cs)
            else if (_view == 'week')
              _buildWeekView(cs)
            else
              _buildListView(cs),
          ],
        )),
      ]),
      floatingActionButton: _readOnly
          ? null
          : FloatingActionButton.extended(
              heroTag: 'new-schedule',
              onPressed: () => _openCreate(),
              backgroundColor: hcTeal,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New schedule'),
            ),
    );
  }

  // ── Hero ──
  Widget _buildHero(ColorScheme cs, Map<String, int> kpis) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: hcTeal.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 14))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 28),
          ),
          const Spacer(),
          if (_loading)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
              child: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ),
        ]),
        const SizedBox(height: 14),
        Text('HOMECARE · OPERATIONS',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
        const SizedBox(height: 4),
        const Text('Schedules', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(_readOnly
            ? 'Your upcoming shifts and visit schedule.'
            : 'Plan, dispatch and track every caregiver visit in real time.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13, height: 1.4)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _heroChip(Icons.calendar_today_rounded, '${kpis['today']} today'),
          _heroChip(Icons.timelapse_rounded, '${kpis['inProgress']} in progress'),
          _heroChip(Icons.check_circle_rounded, '${kpis['completedToday']} completed'),
          _heroChip(Icons.event_available_rounded, '${kpis['upcoming']} upcoming'),
          _heroChip(Icons.error_rounded, '${kpis['missed']} missed'),
        ]),
      ]),
    );
  }

  Widget _heroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── View tabs ──
  Widget _buildViewTabs(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        _tabBtn(cs, 'day', Icons.calendar_today_rounded, 'Day'),
        _tabBtn(cs, 'week', Icons.calendar_view_week_rounded, 'Week'),
        _tabBtn(cs, 'list', Icons.format_list_bulleted_rounded, 'List'),
      ]),
    );
  }

  Widget _tabBtn(ColorScheme cs, String value, IconData icon, String label) {
    final active = _view == value;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() { _view = value; _load(); }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? hcTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 17, color: active ? Colors.white : cs.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : cs.onSurfaceVariant)),
        ]),
      ),
    ));
  }

  // ── Filter bar ──
  Widget _buildFilterBar(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        if (_view != 'list')
          Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _navigate(-1)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: hcTeal.withValues(alpha: 0.12), foregroundColor: hcTeal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: _goToday, child: const Text('Today', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
            IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _navigate(1)),
            const SizedBox(width: 4),
            Expanded(child: Text(_rangeLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13), overflow: TextOverflow.ellipsis)),
          ])
        else
          Container(
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: _readOnly ? 'Search patient, notes…' : 'Search caregiver, patient, notes…',
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: cs.onSurfaceVariant),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setState(() => _search = ''))
                    : null,
                border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        const SizedBox(height: 8),
        // Filter chips row
        SizedBox(
          height: 36,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            _filterChip(cs, 'All', '', 'status'),
            ..._statusOptions.map((s) => _filterChip(cs, _statusLabel(s), s, 'status', color: _statusColor(s))),
            const SizedBox(width: 6),
            _filterChip(cs, 'All shifts', '', 'shift'),
            ..._shiftTypeOptions.map((o) => _filterChip(cs, o['label'] as String, o['value'] as String, 'shift')),
          ]),
        ),
      ]),
    );
  }

  Widget _filterChip(ColorScheme cs, String label, String value, String type, {Color? color}) {
    final current = type == 'status' ? _filterStatus : _filterShiftType;
    final active = current == value;
    final chipColor = color ?? hcTeal;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : cs.onSurfaceVariant)),
        selected: active,
        onSelected: (v) => setState(() {
          if (type == 'status') {
            _filterStatus = v ? value : '';
          } else {
            _filterShiftType = v ? value : '';
          }
        }),
        selectedColor: chipColor,
        backgroundColor: cs.surfaceContainerHighest,
        side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 6), showCheckmark: false,
      ),
    );
  }

  // ── Day view ──
  Widget _buildDayView(ColorScheme cs) {
    final events = _filtered.where((ev) {
      final s = DateTime.tryParse(ev['start_at']?.toString() ?? '')?.toLocal();
      return s != null && _sameDay(s, _cursor);
    }).toList();

    if (events.isEmpty) return _emptyState(cs, 'No visits scheduled', 'Adjust filters or create a new schedule.');

    final hourPx = 56.0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color: cs.surface, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 24 * hourPx + 20,
        child: Stack(children: [
          // Hour lines
          ...List.generate(24, (h) => Positioned(
            top: h * hourPx, left: 56, right: 0,
            child: Container(height: hourPx,
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2), width: 1, style: BorderStyle.solid)))),
          )),
          // Hour labels
          ...List.generate(24, (h) => Positioned(
            top: h * hourPx, left: 0, width: 50,
            child: Padding(padding: const EdgeInsets.only(top: 2, right: 8),
              child: Text('${h == 0 ? 12 : h > 12 ? h - 12 : h}${h < 12 ? "am" : "pm"}',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.6)))),
          )),
          // Events
          ...events.map((ev) {
            final s = DateTime.tryParse(ev['start_at']?.toString() ?? '')?.toLocal();
            final e = DateTime.tryParse(ev['end_at']?.toString() ?? '')?.toLocal();
            if (s == null || e == null) return const SizedBox.shrink();
            final top = (s.hour + s.minute / 60) * hourPx;
            final dur = e.difference(s).inMinutes / 60;
            final height = (dur * hourPx - 4).clamp(40.0, 9999.0);
            return Positioned(
              top: top, left: 60, right: 8, height: height,
              child: _DayEventCard(event: ev, onTap: () => _openDetail(ev)),
            );
          }),
        ]),
      ),
    );
  }

  // ── Week view ──
  Widget _buildWeekView(ColorScheme cs) {
    final weekStart = _rangeStart;
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      decoration: BoxDecoration(
        color: cs.surface, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // Day headers
        Row(children: [
          const SizedBox(width: 40),
          ...List.generate(7, (i) {
            final d = weekStart.add(Duration(days: i));
            final isToday = _sameDay(d, todayStart);
            final dayEvents = _filtered.where((ev) {
              final s = DateTime.tryParse(ev['start_at']?.toString() ?? '')?.toLocal();
              return s != null && _sameDay(s, d);
            }).toList();
            return Expanded(child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isToday ? hcTeal.withValues(alpha: 0.08) : null,
                border: Border(left: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
              ),
              child: Column(children: [
                Text(DateFormat('E').format(d).toUpperCase(),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text('${d.day}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                    color: isToday ? hcTeal : cs.onSurface)),
                if (dayEvents.isNotEmpty)
                  Container(margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: hcTeal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
                    child: Text('${dayEvents.length}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: hcTeal))),
              ]),
            ));
          }),
        ]),
        const Divider(height: 1),
        // Day columns with events
        SizedBox(
          height: 400,
          child: Row(children: [
            SizedBox(width: 40, child: Column(
              children: List.generate(12, (i) {
                final h = i * 2 + 6;
                return SizedBox(height: 60, child: Align(alignment: Alignment.topRight,
                  child: Padding(padding: const EdgeInsets.only(top: 2, right: 6),
                    child: Text('${h > 12 ? h - 12 : h}${h < 12 ? "am" : "pm"}',
                        style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant.withValues(alpha: 0.5))))));
              }),
            )),
            ...List.generate(7, (i) {
              final d = weekStart.add(Duration(days: i));
              final dayEvents = _filtered.where((ev) {
                final s = DateTime.tryParse(ev['start_at']?.toString() ?? '')?.toLocal();
                return s != null && _sameDay(s, d);
              }).toList();
              return Expanded(child: Container(
                decoration: BoxDecoration(border: Border(left: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2)))),
                child: Stack(children: [
                  ...List.generate(12, (j) => Positioned(
                    top: j * 60.0, left: 0, right: 0,
                    child: Container(height: 60, decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.12), style: BorderStyle.solid)))),
                  )),
                  ...dayEvents.map((ev) {
                    final s = DateTime.tryParse(ev['start_at']?.toString() ?? '')?.toLocal();
                    if (s == null) return const SizedBox.shrink();
                    final top = ((s.hour - 6 + s.minute / 60) * 60).clamp(0.0, 720.0);
                    final e = DateTime.tryParse(ev['end_at']?.toString() ?? '')?.toLocal();
                    final dur = e != null ? (e.difference(s).inMinutes / 60 * 60).clamp(30.0, 720.0) : 60.0;
                    return Positioned(top: top, left: 2, right: 2, height: dur,
                      child: GestureDetector(onTap: () => _openDetail(ev),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [_statusColor(ev['status']?.toString()), _statusColor(ev['status']?.toString()).withValues(alpha: 0.7)]),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(DateFormat('HH:mm').format(s), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                            const SizedBox(height: 1),
                            Text(ev['patient_name']?.toString() ?? '—', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                      ),
                    );
                  }),
                ]),
              ));
            }),
          ]),
        ),
      ]),
    );
  }

  // ── List view ──
  Widget _buildListView(ColorScheme cs) {
    final rows = _filtered;
    if (rows.isEmpty) return _emptyState(cs, 'No visits scheduled', 'Adjust filters or create a new schedule.');

    // Group by day
    final groups = <String, List<Map>>{};
    for (final s in rows..sort((a, b) => (a['start_at'] ?? '').toString().compareTo((b['start_at'] ?? '').toString()))) {
      final d = DateTime.tryParse(s['start_at']?.toString() ?? '')?.toLocal();
      final key = d != null ? DateFormat('EEEE, d MMM').format(d) : 'Unscheduled';
      groups.putIfAbsent(key, () => []).add(s);
    }

    return Column(children: groups.entries.map((g) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
          child: Text(g.key.toUpperCase(),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: cs.onSurfaceVariant)),
        ),
        ...g.value.map((s) => _ScheduleCard(event: s, onTap: () => _openDetail(s),
          onQuickAction: (verb) => _quickAction(s, verb))),
      ],
    )).toList());
  }

  // ── Empty state ──
  Widget _emptyState(ColorScheme cs, String title, String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [hcTeal.withValues(alpha: 0.12), hcTeal.withValues(alpha: 0.04)]),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.calendar_today_rounded, size: 38, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 6),
            Text(message, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  // ── Create ──
  void _openCreate() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _CreateEditSheet(),
    ).then((created) { if (created == true) _load(); });
  }

  // ── Detail ──
  void _openDetail(Map ev) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _DetailSheet(event: ev, readOnly: _readOnly, onEdit: () {
        Navigator.pop(context);
        _openEdit(ev);
      }),
    ).then((updated) { if (updated == true) _load(); });
  }

  void _openEdit(Map ev) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _CreateEditSheet(editing: ev),
    ).then((updated) { if (updated == true) _load(); });
  }

  // ── Quick action ──
  Future<void> _quickAction(Map item, String verb) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dio = ref.read(dioProvider);
      Map<String, dynamic> body = {};
      if (verb == 'check_in' || verb == 'check_out') {
        final gps = await hcCaptureGps(context);
        if (gps != null) body['gps'] = gps;
      }
      await dio.post('/homecare/schedules/${item['id']}/$verb/', data: body);
      _load();
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(verb == 'check_in' ? 'Checked in' : verb == 'check_out' ? 'Checked out' : 'Updated'),
          backgroundColor: hcGreen, behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: const Text('Action failed'), backgroundColor: hcRed,
          behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ═════════════════ Day event card ═════════════════
class _DayEventCard extends StatelessWidget {
  final Map event;
  final VoidCallback onTap;
  const _DayEventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = event['status']?.toString();
    final color = _statusColor(status);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.75)]),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(_statusIcon(status), size: 12, color: Colors.white),
            const SizedBox(width: 4),
            Text('${hcTime(event['start_at'])} – ${hcTime(event['end_at'])}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          ]),
          const SizedBox(height: 2),
          Text(event['patient_name']?.toString() ?? 'Patient',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Row(children: [
            Icon(Icons.person_rounded, size: 11, color: Colors.white.withValues(alpha: 0.85)),
            const SizedBox(width: 3),
            Text(event['caregiver_name']?.toString() ?? '—',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ]),
      ),
    );
  }
}

// ═════════════════ Schedule card (list view) ═════════════════
class _ScheduleCard extends StatelessWidget {
  final Map event;
  final VoidCallback onTap;
  final void Function(String verb) onQuickAction;
  const _ScheduleCard({required this.event, required this.onTap, required this.onQuickAction});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = event['status']?.toString();
    final color = _statusColor(status);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: cs.surface, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Accent bar
          Container(height: 3, color: color),
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  // Time block
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('${hcTime(event['start_at'])} – ${hcTime(event['end_at'])}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                  ),
                  const SizedBox(width: 8),
                  HcStatusChip(label: _statusLabel(status).toUpperCase(), color: color, icon: _statusIcon(status)),
                  const Spacer(),
                  if ((event['shift_type'] ?? '').toString().isNotEmpty)
                    Text(_shiftLabel(event['shift_type']?.toString()),
                        style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  HcAvatar(name: event['patient_name']?.toString(), size: 36, color: hcTeal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(event['patient_name']?.toString() ?? '—',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(children: [
                        HcAvatar(name: event['caregiver_name']?.toString(), size: 18, color: hcIndigo),
                        const SizedBox(width: 4),
                        Text(event['caregiver_name']?.toString() ?? '—',
                            style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ]),
                  ),
                ]),
                if ((event['notes'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
                    child: Text(event['notes'].toString(),
                        style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ],
                const SizedBox(height: 10),
                // Quick actions
                Row(children: [
                  if (status == 'scheduled')
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(backgroundColor: hcTeal.withValues(alpha: 0.12), foregroundColor: hcTeal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                      onPressed: () => onQuickAction('check_in'),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.login_rounded, size: 15), const SizedBox(width: 4),
                        const Text('Check-in', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  if (status == 'checked_in')
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(backgroundColor: hcGreen.withValues(alpha: 0.12), foregroundColor: hcGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                      onPressed: () => onQuickAction('check_out'),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.logout_rounded, size: 15), const SizedBox(width: 4),
                        const Text('Check-out', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant, padding: const EdgeInsets.symmetric(horizontal: 10)),
                    onPressed: onTap,
                    icon: const Icon(Icons.visibility_rounded, size: 17),
                    label: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════ Detail sheet ═════════════════
class _DetailSheet extends ConsumerStatefulWidget {
  final Map event;
  final bool readOnly;
  final VoidCallback onEdit;
  const _DetailSheet({required this.event, this.readOnly = false, required this.onEdit});

  @override
  ConsumerState<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends ConsumerState<_DetailSheet> {
  late Map _event;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = _event['status']?.toString();
    final color = _statusColor(status);

    return DraggableScrollableSheet(
      initialChildSize: 0.7, maxChildSize: 0.9, minChildSize: 0.4, expand: false,
      builder: (ctx, controller) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(children: [
          // Gradient header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.75)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_statusIcon(status), color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_statusLabel(status).toUpperCase()} · ${_shiftLabel(_event['shift_type']?.toString())}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  Text('${hcDateTime(_event['start_at'])} – ${hcTime(_event['end_at'])}',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                ])),
                IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(ctx)),
              ]),
            ]),
          ),
          Expanded(child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _infoRow(cs, Icons.person_rounded, 'Caregiver', _event['caregiver_name']?.toString() ?? '—'),
              _infoRow(cs, Icons.accessibility_rounded, 'Patient', _event['patient_name']?.toString() ?? '—'),
              if (_event['check_in_at'] != null) ...[
                _infoRow(cs, Icons.login_rounded, 'Checked in', hcDateTime(_event['check_in_at'])),
                if (_event['gps_check_in'] != null)
                  _infoRow(cs, Icons.location_on_rounded, 'GPS',
                    '${(_event['gps_check_in']['lat'] as num?)?.toStringAsFixed(4) ?? '?'}, '
                    '${(_event['gps_check_in']['lng'] as num?)?.toStringAsFixed(4) ?? '?'}'),
              ],
              if (_event['check_out_at'] != null) ...[
                _infoRow(cs, Icons.logout_rounded, 'Checked out', hcDateTime(_event['check_out_at'])),
                if (_event['check_in_at'] != null)
                  _infoRow(cs, Icons.timer_rounded, 'Duration', _duration(_event['check_in_at'], _event['check_out_at'])),
              ],
              if ((_event['notes'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Notes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                  child: Text(_event['notes'].toString(), style: TextStyle(fontSize: 12.5, height: 1.4, color: cs.onSurface)),
                ),
              ],
              const SizedBox(height: 20),
              // Action buttons
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (status == 'scheduled')
                  _actionBtn(hcTeal, Icons.login_rounded, 'Check-in', () => _doAction('check_in')),
                if (status == 'checked_in')
                  _actionBtn(hcGreen, Icons.logout_rounded, 'Check-out', () => _doAction('check_out')),
                if (!widget.readOnly) ...[
                  if (status == 'scheduled' || status == 'checked_in')
                    _actionBtn(hcAmber, Icons.error_rounded, 'Mark missed', () => _doAction('mark_missed')),
                  if (status == 'scheduled')
                    _actionBtn(hcRed, Icons.cancel_rounded, 'Cancel', () => _doCancel()),
                  _actionBtn(hcIndigo, Icons.edit_rounded, 'Edit', widget.onEdit),
                ],
              ]),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _infoRow(ColorScheme cs, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        SizedBox(width: 90, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface))),
      ]),
    );
  }

  Widget _actionBtn(Color color, IconData icon, String label, VoidCallback onPressed) {
    return FilledButton.tonal(
      style: FilledButton.styleFrom(backgroundColor: color.withValues(alpha: 0.12), foregroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
      onPressed: _acting ? null : onPressed,
      child: _acting
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]),
    );
  }

  Future<void> _doAction(String verb) async {
    setState(() => _acting = true);
    try {
      final dio = ref.read(dioProvider);
      Map<String, dynamic> body = {};
      if (verb == 'check_in' || verb == 'check_out') {
        final gps = await hcCaptureGps(context);
        if (gps != null) body['gps'] = gps;
      }
      final res = await dio.post('/homecare/schedules/${_event['id']}/$verb/', data: body);
      _event = res.data is Map ? res.data as Map : _event;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Updated'), backgroundColor: hcGreen, behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Action failed'), backgroundColor: hcRed, behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _doCancel() async {
    setState(() => _acting = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/homecare/schedules/${_event['id']}/cancel/', data: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Schedule cancelled'), backgroundColor: hcGreen, behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Cancel failed'), backgroundColor: hcRed, behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  String _duration(dynamic a, dynamic b) {
    final start = DateTime.tryParse(a?.toString() ?? '');
    final end = DateTime.tryParse(b?.toString() ?? '');
    if (start == null || end == null) return '—';
    final m = end.difference(start).inMinutes;
    final h = m ~/ 60, mm = m % 60;
    return h > 0 ? '$h h $mm m' : '$mm m';
  }
}

// ═════════════════ Create / Edit sheet ═════════════════
class _CreateEditSheet extends ConsumerStatefulWidget {
  final Map? editing;
  const _CreateEditSheet({this.editing});

  @override
  ConsumerState<_CreateEditSheet> createState() => _CreateEditSheetState();
}

class _CreateEditSheetState extends ConsumerState<_CreateEditSheet> {
  int? _caregiverId;
  int? _patientId;
  String _shiftType = 'visit';
  DateTime? _start;
  DateTime? _end;
  final _notes = TextEditingController();
  String _recurrenceMode = 'none';
  List<String> _byday = [];
  DateTime? _until;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.editing != null) {
      final e = widget.editing!;
      _caregiverId = e['caregiver'] as int?;
      _patientId = e['patient'] as int?;
      _shiftType = e['shift_type']?.toString() ?? 'visit';
      _start = DateTime.tryParse(e['start_at']?.toString() ?? '')?.toLocal();
      _end = DateTime.tryParse(e['end_at']?.toString() ?? '')?.toLocal();
      _notes.text = e['notes']?.toString() ?? '';
      final rec = e['recurrence'] as Map?;
      _recurrenceMode = rec?['freq']?.toString() ?? 'none';
      _byday = (rec?['byday'] as List?)?.cast<String>() ?? [];
      if (rec?['until'] != null) {
        _until = DateTime.tryParse(rec!['until'].toString())?.toLocal();
      }
    }
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final d = await showDatePicker(
      context: context, initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _submit() async {
    if (_caregiverId == null || _patientId == null || _start == null || _end == null) {
      setState(() => _error = 'Caregiver, patient, start and end are required.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final dio = ref.read(dioProvider);
      final recurrence = _recurrenceMode == 'none' ? <String, dynamic>{} : {
        'freq': _recurrenceMode,
        if (_recurrenceMode == 'weekly') 'byday': _byday,
        if (_until != null) 'until': _until!.toUtc().toIso8601String(),
      };
      final payload = {
        'caregiver': _caregiverId,
        'patient': _patientId,
        'start_at': _start!.toUtc().toIso8601String(),
        'end_at': _end!.toUtc().toIso8601String(),
        'shift_type': _shiftType,
        'notes': _notes.text.trim(),
        'recurrence': recurrence,
      };
      if (widget.editing != null) {
        await dio.patch('/homecare/schedules/${widget.editing!['id']}/', data: payload);
      } else {
        await dio.post('/homecare/schedules/', data: payload);
      }
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.editing != null ? 'Schedule updated' : 'Schedule created'),
          backgroundColor: hcGreen, behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      String msg = 'Could not save schedule.';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map && data.isNotEmpty) {
          final first = data.entries.first;
          msg = '${first.key}: ${first.value is List ? (first.value as List).first : first.value}';
        }
      } catch (_) {}
      if (mounted) setState(() { _error = msg; _saving = false; });
    }
  }

  Future<void> _delete() async {
    if (widget.editing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(Icons.delete_rounded, color: hcRed, size: 22), const SizedBox(width: 10), const Text('Delete schedule?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))]),
        content: const Text('This schedule will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: hcRed), icon: const Icon(Icons.delete_rounded, size: 18), label: const Text('Delete'), onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/homecare/schedules/${widget.editing!['id']}/');
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Schedule deleted'), backgroundColor: hcGreen,
          behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to delete'), backgroundColor: hcRed,
          behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final options = ref.watch(_optionsProvider);
    final fmt = DateFormat('EEE d MMM · HH:mm');
    final isEdit = widget.editing != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF14B8A6)], begin: Alignment.topLeft, end: Alignment.topRight),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.all(20),
            child: options.when(
              loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SizedBox(height: 120, child: Center(child: Text('Could not load options.'))),
              data: (opts) {
                final caregivers = (opts['caregivers'] as List).cast<Map>();
                final patients = (opts['patients'] as List).cast<Map>();
                return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Row(children: [
                    Container(padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: hcTeal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                        child: Icon(isEdit ? Icons.edit_calendar_rounded : Icons.add_circle_rounded, color: hcTeal, size: 22)),
                    const SizedBox(width: 12),
                    Text(isEdit ? 'Edit schedule' : 'New schedule', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  ]),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    initialValue: _caregiverId,
                    decoration: InputDecoration(labelText: 'Caregiver *', prefixIcon: Icon(Icons.person_rounded, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                    items: caregivers.map((c) => DropdownMenuItem(value: c['id'] as int,
                        child: Text((c['user']?['full_name'] ?? c['user']?['email'] ?? '#${c['id']}').toString(), overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => _caregiverId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _patientId,
                    decoration: InputDecoration(labelText: 'Patient *', prefixIcon: Icon(Icons.accessibility_rounded, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                    items: patients.map((p) => DropdownMenuItem(value: p['id'] as int,
                        child: Text((p['patient_name'] ?? p['user']?['full_name'] ?? '#${p['id']}').toString(), overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setState(() => _patientId = v),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () async { final v = await _pickDateTime(_start ?? DateTime.now()); if (v != null) setState(() => _start = v); },
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: Text(_start != null ? fmt.format(_start!) : 'Start *', style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () async { final v = await _pickDateTime(_end ?? (_start?.add(const Duration(hours: 1)) ?? DateTime.now())); if (v != null) setState(() => _end = v); },
                      icon: const Icon(Icons.stop_rounded, size: 16),
                      label: Text(_end != null ? fmt.format(_end!) : 'End *', style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    )),
                  ]),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _shiftType,
                    decoration: InputDecoration(labelText: 'Shift type', prefixIcon: Icon(Icons.work_outline_rounded, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                    items: _shiftTypeOptions.map((o) => DropdownMenuItem(value: o['value'] as String, child: Text(o['label'] as String))).toList(),
                    onChanged: (v) => setState(() => _shiftType = v ?? 'visit'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _recurrenceMode,
                    decoration: InputDecoration(labelText: 'Recurrence', prefixIcon: Icon(Icons.repeat_rounded, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                    items: _recurrenceModes.map((o) => DropdownMenuItem(value: o['value'] as String, child: Text(o['label'] as String))).toList(),
                    onChanged: (v) => setState(() => _recurrenceMode = v ?? 'none'),
                  ),
                  if (_recurrenceMode == 'weekly') ...[
                    const SizedBox(height: 10),
                    Text('Repeat on', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: _weekdays.map((d) {
                      final selected = _byday.contains(d['value']);
                      return FilterChip(
                        label: Text(d['short'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : cs.onSurfaceVariant)),
                        selected: selected,
                        onSelected: (v) => setState(() {
                          if (v) {
                            _byday.add(d['value'] as String);
                          } else {
                            _byday.remove(d['value']);
                          }
                        }),
                        selectedColor: hcTeal, backgroundColor: cs.surfaceContainerHighest,
                        side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        showCheckmark: false, padding: const EdgeInsets.symmetric(horizontal: 8),
                      );
                    }).toList()),
                  ],
                  if (_recurrenceMode != 'none') ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(context: context, initialDate: _until ?? DateTime.now().add(const Duration(days: 30)), firstDate: DateTime.now(), lastDate: DateTime(2100));
                        if (d != null) setState(() => _until = d);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: 'Repeat until', prefixIcon: Icon(Icons.event_available_rounded, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                        child: Text(_until != null ? DateFormat('d MMM yyyy').format(_until!) : 'No end date', style: TextStyle(fontSize: 14, color: _until == null ? cs.onSurfaceVariant : cs.onSurface)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notes, maxLines: 2,
                    decoration: InputDecoration(labelText: 'Notes', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: hcRed.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [Icon(Icons.error_outline_rounded, size: 16, color: hcRed), const SizedBox(width: 8), Expanded(child: Text(_error!, style: TextStyle(fontSize: 12, color: hcRed)))])),
                  ],
                  const SizedBox(height: 16),
                  Row(children: [
                    if (isEdit)
                      TextButton.icon(style: TextButton.styleFrom(foregroundColor: hcRed), onPressed: _saving ? null : _delete,
                          icon: const Icon(Icons.delete_rounded, size: 18), label: const Text('Delete')),
                    const Spacer(),
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: hcTeal, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: _saving ? null : _submit,
                      icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded, size: 20),
                      label: Text(isEdit ? 'Save' : 'Create', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ]),
                  const SizedBox(height: 20),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }
}
