import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import 'hc_common.dart';

const _statusMeta = {
  'scheduled':  {'label': 'Scheduled',  'icon': Icons.schedule_rounded,    'color': Color(0xFF2563EB)},
  'checked_in': {'label': 'In progress', 'icon': Icons.timelapse_rounded,   'color': Color(0xFF0D9488)},
  'completed':  {'label': 'Completed',  'icon': Icons.check_circle_rounded, 'color': Color(0xFF16A34A)},
  'missed':     {'label': 'Missed',     'icon': Icons.error_rounded,         'color': Color(0xFFF59E0B)},
  'cancelled':  {'label': 'Cancelled',  'icon': Icons.cancel_rounded,         'color': Color(0xFF64748B)},
};

const _statusOptions = ['scheduled', 'checked_in', 'completed', 'missed', 'cancelled'];

const _shiftTypeOptions = [
  {'value': 'visit', 'label': 'Single Visit'},
  {'value': 'live_in', 'label': 'Live-in'},
  {'value': 'on_call', 'label': 'On Call'},
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

/// Provider resolving the signed-in caregiver's own record (id + name).
final _meCaregiverProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/homecare/caregivers/me/');
  final d = res.data;
  return d is Map ? d : <String, dynamic>{};
});

/// Caregiver's assigned patients (read-only).
final _myPatientsProvider = FutureProvider.autoDispose((ref) async {
  final me = await ref.watch(_meCaregiverProvider.future);
  final id = me['id'];
  if (id == null) return <Map>[];
  final dio = ref.read(dioProvider);
  final res = await dio.get('/homecare/caregivers/$id/assigned-patients/');
  final list = res.data is List ? res.data : (res.data?['results'] ?? []);
  return (list as List).cast<Map>();
});

/// Isolated, read-only assignments view for caregivers: shows only their own
/// shifts and the patients assigned to them. No add / edit / delete / reassign.
class HomecareMyAssignmentsScreen extends ConsumerStatefulWidget {
  const HomecareMyAssignmentsScreen({super.key});

  @override
  ConsumerState<HomecareMyAssignmentsScreen> createState() =>
      _HomecareMyAssignmentsScreenState();
}

class _HomecareMyAssignmentsScreenState
    extends ConsumerState<HomecareMyAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _sheetDate = hcDateOffset(0);
  String _filterStatus = '';
  List<Map> _shifts = [];
  bool _loadingShifts = false;
  int? _meCaregiverId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_meCaregiverProvider.future).then((me) {
        _meCaregiverId = me['id'] as int?;
        _loadShifts();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _hcYMD(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadShifts() async {
    if (_meCaregiverId == null) return;
    setState(() => _loadingShifts = true);
    try {
      final start = DateTime.tryParse('$_sheetDate\T00:00') ?? DateTime.now();
      final end = start.add(const Duration(days: 1));
      final data = await hcFetchAll(ref, '/homecare/schedules/', params: {
        'page_size': 500,
        'caregiver': _meCaregiverId,
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

  List<Map> get _filteredShifts {
    final out = _shifts.where((s) {
      if (_filterStatus.isNotEmpty && s['status'] != _filterStatus) return false;
      return hcSplitDateTime(s['start_at']).date == _sheetDate;
    }).toList();
    out.sort((a, b) =>
        DateTime.parse(a['start_at']).compareTo(DateTime.parse(b['start_at'])));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final me = ref.watch(_meCaregiverProvider);
    final caregiverName = me.maybeWhen(
      data: (m) => (m['user']?['full_name'] ?? m['name'] ?? 'You').toString(),
      orElse: () => 'You',
    );
    final todayShifts = _shifts.where((s) =>
        hcSplitDateTime(s['start_at']).date == hcDateOffset(0) &&
        s['status'] != 'cancelled').length;
    final completed = _shifts.where((s) =>
        hcSplitDateTime(s['start_at']).date == hcDateOffset(0) &&
        s['status'] == 'completed').length;

    return Scaffold(
      body: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(child: HcHero(
            eyebrow: 'MY SHIFTS',
            title: 'My assignments',
            subtitle: 'Your upcoming shifts and the patients assigned to you.',
            icon: Icons.swap_horiz_rounded,
            gradient: const [Color(0xFF6D28D9), Color(0xFF7C3AED), Color(0xFFA78BFA)],
            chips: [
              HcHeroChip(icon: Icons.event_rounded, label: '$todayShifts today'),
              HcHeroChip(icon: Icons.check_circle_rounded, label: '$completed done'),
              HcHeroChip(icon: Icons.person_rounded, label: caregiverName),
            ],
          )),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: hcPurple,
                unselectedLabelColor: cs.onSurfaceVariant,
                indicatorColor: hcPurple,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(icon: Icon(Icons.event_note_rounded, size: 18), text: 'My shifts'),
                  Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'My patients'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildShiftsTab(cs),
            _buildPatientsTab(cs),
          ],
        ),
      ),
    );
  }

  // ── My shifts tab ──
  Widget _buildShiftsTab(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildDateNav(cs),
        const SizedBox(height: 10),
        _buildStatusChips(cs),
        const SizedBox(height: 12),
        if (_loadingShifts)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (_filteredShifts.isEmpty)
          _empty(cs, Icons.event_busy_rounded, 'No shifts', 'Nothing scheduled for this day.')
        else
          ..._filteredShifts.map((s) => _ShiftCard(shift: s, onTap: () => _openDetail(s))),
      ],
    );
  }

  Widget _buildDateNav(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Expanded(
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'yesterday', label: Text('Yest', style: TextStyle(fontSize: 12))),
              ButtonSegment(value: 'today', label: Text('Today', style: TextStyle(fontSize: 12))),
              ButtonSegment(value: 'tomorrow', label: Text('Tom', style: TextStyle(fontSize: 12))),
            ],
            selected: {
              _sheetDate == hcDateOffset(-1) ? 'yesterday'
              : _sheetDate == hcDateOffset(0) ? 'today'
              : _sheetDate == hcDateOffset(1) ? 'tomorrow' : 'custom',
            },
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
          icon: _loadingShifts
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh_rounded, size: 16),
        ),
      ]),
    );
  }

  Widget _buildStatusChips(ColorScheme cs) {
    return SizedBox(
      height: 36,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        _chip(cs, 'All', ''),
        ..._statusOptions.map((s) => _chip(cs, _statusLabel(s), s, color: _statusColor(s))),
      ]),
    );
  }

  Widget _chip(ColorScheme cs, String label, String value, {Color? color}) {
    final active = _filterStatus == value;
    final chipColor = color ?? hcPurple;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : cs.onSurfaceVariant)),
        selected: active,
        onSelected: (v) => setState(() => _filterStatus = v ? value : ''),
        selectedColor: chipColor,
        backgroundColor: cs.surfaceContainerHighest,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        showCheckmark: false,
      ),
    );
  }

  Widget _empty(ColorScheme cs, IconData icon, String title, String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [hcPurple.withValues(alpha: 0.12), hcPurple.withValues(alpha: 0.04)]),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 38, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
        ),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 6),
        Text(message, style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
      ])),
    );
  }

  void _openDetail(Map s) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final status = s['status']?.toString();
        final color = _statusColor(status);
        return DraggableScrollableSheet(
          initialChildSize: 0.6, maxChildSize: 0.85, minChildSize: 0.4, expand: false,
          builder: (c, controller) => Container(
            decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.75)]),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(children: [
                  Icon(_statusIcon(status), color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_statusLabel(status).toUpperCase()} · ${_shiftLabel(s['shift_type']?.toString())}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    Text('${hcDateTime(s['start_at'])} – ${hcTime(s['end_at'])}',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  ])),
                  IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(c)),
                ]),
              ),
              Expanded(child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _infoRow(cs, Icons.accessibility_rounded, 'Patient', s['patient_name']?.toString() ?? '—'),
                  if (s['check_in_at'] != null)
                    _infoRow(cs, Icons.login_rounded, 'Checked in', hcDateTime(s['check_in_at'])),
                  if (s['check_out_at'] != null)
                    _infoRow(cs, Icons.logout_rounded, 'Checked out', hcDateTime(s['check_out_at'])),
                  if ((s['notes'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Notes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                      child: Text(s['notes'].toString(), style: TextStyle(fontSize: 12.5, height: 1.4, color: cs.onSurface)),
                    ),
                  ],
                ]),
              )),
            ]),
          ),
        );
      },
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

  // ── My patients tab ──
  Widget _buildPatientsTab(ColorScheme cs) {
    final patients = ref.watch(_myPatientsProvider);
    return patients.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _empty(cs, Icons.error_outline_rounded, 'Could not load', 'Failed to load your assigned patients.'),
      data: (list) {
        if (list.isEmpty) return _empty(cs, Icons.people_outline_rounded, 'No patients', 'No patients are assigned to you yet.');
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: list.length,
          itemBuilder: (ctx, i) {
            final p = list[i];
            final name = (p['patient_name'] ?? p['user']?['full_name'] ?? '#${p['id']}').toString();
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => context.go('/homecare/patients/${p['id']}'),
                leading: HcAvatar(name: name, color: hcTeal, size: 42),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    if (p['medical_record_number'] != null) 'MRN ${p['medical_record_number']}',
                    if (p['primary_diagnosis'] != null) p['primary_diagnosis'],
                  ].join(' · '),
                  style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final Map shift;
  final VoidCallback onTap;
  const _ShiftCard({required this.shift, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = shift['status']?.toString();
    final color = _statusColor(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surface, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(height: 3, color: color),
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('${hcTime(shift['start_at'])} – ${hcTime(shift['end_at'])}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                  ),
                  const SizedBox(width: 8),
                  HcStatusChip(label: _statusLabel(status).toUpperCase(), color: color, icon: _statusIcon(status)),
                  const Spacer(),
                  if ((shift['shift_type'] ?? '').toString().isNotEmpty)
                    Text(_shiftLabel(shift['shift_type']?.toString()),
                        style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  HcAvatar(name: shift['patient_name']?.toString(), size: 36, color: hcTeal),
                  const SizedBox(width: 8),
                  Expanded(child: Text(shift['patient_name']?.toString() ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                if ((shift['notes'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
                    child: Text(shift['notes'].toString(),
                        style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
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
    return Container(color: Theme.of(context).scaffoldBackgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => tabBar != oldDelegate.tabBar;
}
