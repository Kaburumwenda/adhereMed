import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api.dart';
import '../../providers/auth_provider.dart';
import 'hc_common.dart';

final _dashDoseFilter = StateProvider.autoDispose((_) => '7d');
final _dashDoseFrom = StateProvider.autoDispose((_) => '');
final _dashDoseTo = StateProvider.autoDispose((_) => '');

final _dashDosesProvider = FutureProvider.autoDispose((ref) async {
  final filter = ref.watch(_dashDoseFilter);
  final now = DateTime.now();
  DateTime? from;
  DateTime? to;
  switch (filter) {
    case 'today':
      from = DateTime(now.year, now.month, now.day);
      to = from.add(const Duration(days: 1));
    case 'yesterday':
      from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
      to = DateTime(now.year, now.month, now.day);
    case '7d':
      from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      to = now.add(const Duration(days: 1));
    case '30d':
      from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
      to = now.add(const Duration(days: 1));
    case 'year':
      from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 365));
      to = now.add(const Duration(days: 1));
    case 'custom':
      final rawFrom = ref.watch(_dashDoseFrom);
      final rawTo = ref.watch(_dashDoseTo);
      if (rawFrom.isNotEmpty) from = DateTime.tryParse(rawFrom)?.toLocal();
      if (rawTo.isNotEmpty) to = DateTime.tryParse(rawTo)?.toLocal();
  }
  final params = <String, dynamic>{'page_size': 2000};
  if (from != null) params['from'] = from.toUtc().toIso8601String();
  if (to != null) params['to'] = to.toUtc().toIso8601String();
  return hcFetchAll(ref, '/homecare/doses/', params: params);
});

// ── Admin: dashboard summary (kpis, doses, trend, visits, escalations) ──
final _adminDashProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/homecare/dashboard/summary/');
  return res.data as Map<String, dynamic>;
});

// ── Caregiver: my-day + my patients + week shifts ──
final _caregiverHomeProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: (now.weekday - 1)));
  final weekEnd = monday.add(const Duration(days: 7));
  final results = await Future.wait([
    dio.get('/homecare/caregivers/me/my-day/'),
    hcFetchAll(ref, '/homecare/patients/',
        params: {'is_active': 'true', 'page_size': 100}),
    hcFetchAll(ref, '/homecare/schedules/', params: {
      'start_after': monday.toUtc().toIso8601String(),
      'end_before': weekEnd.toUtc().toIso8601String(),
      'page_size': 200,
    }),
    // Pre-warm the shared dose-filtered provider so panels render on load.
    hcFetchAll(ref, '/homecare/doses/', params: {'page_size': 2000, 'from': DateTime.now().subtract(const Duration(days: 6)).toUtc().toIso8601String(), 'to': DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String()}),
  ]);
  return {
    'day': (results[0] as dynamic).data as Map<String, dynamic>,
    'patients': results[1] as List,
    'week': results[2] as List,
  };
});

class HomecareDashboardScreen extends ConsumerWidget {
  const HomecareDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).user?.role ?? '';
    return role == 'caregiver'
        ? const _CaregiverHome()
        : const _AdminDashboard();
  }
}

// ═════════════════════════════════════════════════════════════════
//  ADMIN DASHBOARD
// ═════════════════════════════════════════════════════════════════
class _AdminDashboard extends ConsumerWidget {
  const _AdminDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(_adminDashProvider);
    final auth = ref.watch(authProvider);

    return HcAsyncBody(
      value: dash,
      onRefresh: () async => ref.refresh(_adminDashProvider.future),
      builder: (d) {
        final kpis = (d['kpis'] as Map?) ?? {};
        final doses = (d['today_doses'] as Map?) ?? {};
        final visits = (d['upcoming_visits'] as List?) ?? [];
        final escalations = (d['recent_escalations'] as List?) ?? [];
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: 'COMMAND CENTRE',
              title: 'Hello, ${auth.user?.firstName ?? 'Admin'}',
              subtitle: DateFormat('EEEE, d MMMM').format(DateTime.now()),
              icon: Icons.monitor_heart_rounded,
              chips: [
                HcHeroChip(
                    icon: Icons.people_rounded,
                    label: '${kpis['active_patients'] ?? 0} active patients'),
                HcHeroChip(
                    icon: Icons.medical_services_rounded,
                    label: '${kpis['caregivers_on_duty'] ?? 0} on duty'),
              ],
            ).animate().fadeIn(duration: 300.ms),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, c) {
                  final cardW = (c.maxWidth - 10) / 2;
                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: cardW / (cardW / 2.2 + 20),
                    children: [
                      HcKpi(
                          label: 'Active patients',
                      value: '${kpis['active_patients'] ?? 0}',
                      icon: Icons.favorite_rounded,
                      color: hcTeal,
                      onTap: () => context.go('/homecare/patients')),
                  HcKpi(
                      label: 'Caregivers',
                      value:
                          '${kpis['caregivers_on_duty'] ?? 0}/${kpis['caregivers_total'] ?? 0}',
                      hint: 'On duty / total',
                      icon: Icons.medical_services_rounded,
                      color: hcBlue,
                      onTap: () => context.go('/homecare/caregivers')),
                  HcKpi(
                      label: 'Adherence today',
                      value: '${kpis['adherence_today'] ?? 0}%',
                      icon: Icons.pie_chart_rounded,
                      color: hcPurple),
                  HcKpi(
                      label: 'Open escalations',
                      value: '${kpis['open_escalations'] ?? 0}',
                      icon: Icons.notification_important_rounded,
                      color: hcRed,
                      onTap: () => context.go('/homecare/escalations')),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _TodayDoses(doses: doses),
            const SizedBox(height: 16),
            _DoseAdherencePanel(),
            const SizedBox(height: 16),
            _FilteredDosesPanel(),
            const SizedBox(height: 16),
            HcPanel(
              title: 'Upcoming visits',
              subtitle: 'Next scheduled care visits',
              icon: Icons.event_rounded,
              color: hcBlue,
              action: TextButton(
                  onPressed: () => context.go('/homecare/assignments'),
                  child: const Text('All shifts')),
              child: visits.isEmpty
                  ? const _EmptyLine(text: 'No upcoming visits')
                  : Column(
                      children: visits.take(6).map<Widget>((v) {
                      return _VisitRow(visit: v as Map);
                    }).toList()),
            ),
            HcPanel(
              title: 'Recent escalations',
              subtitle: 'Patients flagged for attention',
              icon: Icons.warning_amber_rounded,
              color: hcRed,
              action: TextButton(
                  onPressed: () => context.go('/homecare/escalations'),
                  child: const Text('Triage')),
              child: escalations.isEmpty
                  ? const _EmptyLine(text: 'No recent escalations')
                  : Column(
                      children: escalations.take(5).map<Widget>((e) {
                        final m = e as Map;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: HcAvatar(
                              name: m['patient_name']?.toString(),
                              color: hcSeverityColor(
                                  m['severity']?.toString())),
                          title: Text(m['patient_name']?.toString() ?? '—',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: Text(m['reason']?.toString() ?? '',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: HcStatusChip(
                              label: hcLabel(m['severity']?.toString()),
                              color:
                                  hcSeverityColor(m['severity']?.toString())),
                        );
                      }).toList(),
                    ),
            ),
            _QuickLinks(isCaregiver: false),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  CAREGIVER HOME (mirrors web CaregiverHomeDashboard)
// ═════════════════════════════════════════════════════════════════
class _CaregiverHome extends ConsumerWidget {
  const _CaregiverHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(_caregiverHomeProvider);
    final auth = ref.watch(authProvider);

    return HcAsyncBody(
      value: home,
      onRefresh: () async => ref.refresh(_caregiverHomeProvider.future),
      builder: (d) {
        final day = d['day'] as Map<String, dynamic>;
        final caregiver = (day['caregiver'] as Map?) ?? {};
        final visits = (day['visits'] as List?) ?? [];
        final doses = (day['doses'] as List?) ?? [];
        final patients = (d['patients'] as List?) ?? [];
        final week = (d['week'] as List?) ?? [];

        final pendingDoses =
            doses.where((x) => x['status'] == 'pending').length;
        final doneVisits =
            visits.where((x) => x['status'] == 'completed').length;
        final hour = DateTime.now().hour;
        final greeting = hour < 12
            ? 'Good morning'
            : hour < 17
                ? 'Good afternoon'
                : 'Good evening';
        final gradient = hour < 12
            ? const [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)]
            : hour < 17
                ? const [Color(0xFF0E7490), Color(0xFF0891B2), Color(0xFF06B6D4)]
                : const [Color(0xFF3730A3), Color(0xFF4F46E5), Color(0xFF6366F1)];

        // Next visit = earliest non-final today
        final upcoming = visits
            .where((v) => !['completed', 'cancelled', 'missed']
                .contains(v['status']))
            .toList()
          ..sort((a, b) => (a['start_at'] ?? '')
              .toString()
              .compareTo((b['start_at'] ?? '').toString()));
        final next = upcoming.isNotEmpty ? upcoming.first as Map : null;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: greeting.toUpperCase(),
              title: auth.user?.fullName ?? 'Caregiver',
              subtitle: DateFormat('EEEE, d MMMM').format(DateTime.now()),
              icon: Icons.volunteer_activism_rounded,
              gradient: gradient,
              chips: [
                HcHeroChip(
                    icon: Icons.star_rounded,
                    label: '${caregiver['rating'] ?? 0} rating'),
                HcHeroChip(
                    icon: Icons.people_rounded,
                    label: '${patients.length} patients'),
                HcHeroChip(
                    icon: (caregiver['is_available'] == true)
                        ? Icons.check_circle_rounded
                        : Icons.pause_circle_rounded,
                    label: (caregiver['is_available'] == true)
                        ? 'Available'
                        : 'Off duty'),
              ],
            ).animate().fadeIn(duration: 300.ms),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, c) {
                  final cardW = (c.maxWidth - 10) / 2;
                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: cardW / (cardW / 2.2 + 20),
                    children: [
                  HcKpi(
                      label: 'Visits today',
                      value: '${visits.length}',
                      hint: '$doneVisits done',
                      icon: Icons.calendar_today_rounded,
                      color: hcTeal,
                      onTap: () => context.go('/homecare/my-day')),
                  HcKpi(
                      label: 'Pending doses',
                      value: '$pendingDoses',
                      icon: Icons.medication_rounded,
                      color: hcBlue,
                      onTap: () => context.go('/homecare/my-day')),
                  HcKpi(
                      label: 'This week',
                      value: '${week.length}',
                      hint: 'Scheduled shifts',
                      icon: Icons.date_range_rounded,
                      color: hcAmber,
                      onTap: () => context.go('/homecare/assignments')),
                  HcKpi(
                      label: 'Total visits',
                      value: '${caregiver['total_visits'] ?? 0}',
                      hint: 'All time',
                      icon: Icons.verified_rounded,
                      color: hcGreen),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            _DoseAdherencePanel(),
            const SizedBox(height: 16),
            _FilteredDosesPanel(),
            const SizedBox(height: 16),
            if (next != null)
              HcPanel(
                title: 'Up next',
                subtitle: 'Your next scheduled visit',
                icon: Icons.near_me_rounded,
                color: hcTeal,
                action: TextButton(
                    onPressed: () => context.go('/homecare/my-day'),
                    child: const Text('My Day')),
                child: Column(children: [
                  _VisitRow(visit: next, showDirections: true),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.go('/homecare/my-day'),
                        icon: const Icon(Icons.login_rounded, size: 18),
                        label: const Text('Check in'),
                      ),
                    ),
                  ]),
                ]),
              ),
            HcPanel(
              title: 'My patients',
              subtitle: 'People currently under your care',
              icon: Icons.people_alt_rounded,
              color: hcTeal,
              action: TextButton(
                  onPressed: () => context.go('/homecare/patients'),
                  child: const Text('All')),
              child: patients.isEmpty
                  ? const _EmptyLine(text: 'No patients assigned')
                  : Column(
                      children: patients.take(6).map<Widget>((p) {
                        final m = p as Map;
                        final risk = m['risk_level']?.toString() ?? 'low';
                        final adherence = m['adherence_rate'];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onTap: () =>
                              context.go('/homecare/patients/${m['id']}'),
                          leading: HcAvatar(
                              name: m['patient_name']?.toString(),
                              color: hcRiskColor(risk)),
                          title: Text(m['patient_name']?.toString() ?? '—',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: Text(
                              m['medical_record_number']?.toString() ?? '',
                              style: const TextStyle(fontSize: 11)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              HcStatusChip(
                                  label: '${risk.toUpperCase()} RISK',
                                  color: hcRiskColor(risk)),
                              const SizedBox(height: 3),
                              Text(
                                  adherence != null
                                      ? 'Adherence $adherence%'
                                      : 'Adherence N/A',
                                  style: const TextStyle(fontSize: 10.5)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            _QuickLinks(isCaregiver: true),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  Shared pieces
// ═════════════════════════════════════════════════════════════════
class _TodayDoses extends StatelessWidget {
  final Map doses;
  const _TodayDoses({required this.doses});

  @override
  Widget build(BuildContext context) {
    final total = (doses['total'] ?? 0) as num;
    final taken = (doses['taken'] ?? 0) as num;
    final pending = (doses['pending'] ?? 0) as num;
    final missed = (doses['missed'] ?? 0) as num;
    final pct = total > 0 ? taken / total : 0.0;
    return HcPanel(
      title: "Today's doses",
      subtitle: 'Medication administration across all patients',
      icon: Icons.medication_rounded,
      color: hcPurple,
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
              value: pct.toDouble(), minHeight: 8, color: hcGreen),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _DoseStat(label: 'Taken', value: '$taken', color: hcGreen),
            _DoseStat(label: 'Pending', value: '$pending', color: hcAmber),
            _DoseStat(label: 'Missed', value: '$missed', color: hcRed),
            _DoseStat(label: 'Total', value: '$total', color: hcSlate),
          ],
        ),
      ]),
    );
  }
}

class _DoseStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _DoseStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w800, color: color)),
      Text(label,
          style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }
}

class _VisitRow extends StatelessWidget {
  final Map visit;
  final bool showDirections;
  const _VisitRow({required this.visit, this.showDirections = false});

  @override
  Widget build(BuildContext context) {
    final status = visit['status']?.toString();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: HcAvatar(
          name: visit['patient_name']?.toString(),
          color: hcVisitStatusColor(status)),
      title: Text(visit['patient_name']?.toString() ?? '—',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      subtitle: Text(
        '${hcTimeRange(visit['start_at'], visit['end_at'])}'
        '${(visit['patient_address'] ?? '').toString().isNotEmpty ? ' · ${visit['patient_address']}' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11.5),
      ),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (showDirections)
          IconButton(
            icon: const Icon(Icons.directions_rounded, color: hcIndigo),
            tooltip: 'Directions',
            onPressed: () => hcOpenDirections(
              context,
              destLat: double.tryParse('${visit['patient_address_lat']}'),
              destLng: double.tryParse('${visit['patient_address_lng']}'),
              address: visit['patient_address']?.toString(),
            ),
          ),
        HcStatusChip(
            label: hcLabel(status), color: hcVisitStatusColor(status)),
      ]),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  final bool isCaregiver;
  const _QuickLinks({required this.isCaregiver});

  @override
  Widget build(BuildContext context) {
    final links = isCaregiver
        ? const [
            (_QL(Icons.today_rounded, 'My Day', '/homecare/my-day', hcTeal)),
            (_QL(Icons.volunteer_activism_rounded, 'Patient Care', '/homecare/patient-care', hcGreen)),
            (_QL(Icons.medication_rounded, 'Doses', '/homecare/doses', hcBlue)),
            (_QL(Icons.monitor_heart_rounded, 'Vitals', '/homecare/vitals', hcRose)),
            (_QL(Icons.assignment_rounded, 'Assessments', '/homecare/assessments', hcPurple)),
            (_QL(Icons.event_note_rounded, 'My Shifts', '/homecare/assignments', hcAmber)),
          ]
        : const [
            (_QL(Icons.person_add_alt_1_rounded, 'Enroll patient', '/homecare/patients/new', hcTeal)),
            (_QL(Icons.volunteer_activism_rounded, 'Patient Care', '/homecare/patient-care', hcGreen)),
            (_QL(Icons.medical_services_rounded, 'Caregivers', '/homecare/caregivers', hcBlue)),
            (_QL(Icons.medication_rounded, 'Doses', '/homecare/doses', hcIndigo)),
            (_QL(Icons.monitor_heart_rounded, 'Vitals', '/homecare/vitals', hcRose)),
            (_QL(Icons.assignment_rounded, 'Assessments', '/homecare/assessments', hcPurple)),
            (_QL(Icons.event_note_rounded, 'Schedules', '/homecare/schedules', hcAmber)),
            (_QL(Icons.notification_important_rounded, 'Escalations', '/homecare/escalations', hcRed)),
          ];
    return HcPanel(
      title: 'Quick actions',
      icon: Icons.bolt_rounded,
      color: hcPurple,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.6,
        children: links
            .map((l) => Material(
                  color: l.color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.go(l.path),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(children: [
                        Icon(l.icon, color: l.color, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(l.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: l.color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5))),
                      ]),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _QL {
  final IconData icon;
  final String label;
  final String path;
  final Color color;
  const _QL(this.icon, this.label, this.path, this.color);
}

class _EmptyLine extends StatelessWidget {
  final String text;
  const _EmptyLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
          child: Text(text,
              style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant))),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  Shared dashboard panels — adherence chart + filtered doses
// ═════════════════════════════════════════════════════════════════

class _DoseAdherencePanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doses = ref.watch(_dashDosesProvider);
    final filter = ref.watch(_dashDoseFilter);
    final from = ref.watch(_dashDoseFrom);
    final to = ref.watch(_dashDoseTo);

    // Daily adherence computation
    final byDay = <String, int>{};
    final byDayMissed = <String, int>{};
    for (final d in (doses.valueOrNull ?? const []).cast<Map>()) {
      final st = (d['status'] ?? '').toString();
      if (st != 'taken' && st != 'missed') continue;
      var ts = d['scheduled_at'] ?? d['administered_at'];
      if (ts == null) continue;
      final dt = DateTime.tryParse(ts.toString())?.toLocal();
      if (dt == null) continue;
      final key = DateFormat('yyyy-MM-dd').format(dt);
      byDay[key] = (byDay[key] ?? 0) + 1;
      if (st == 'missed') byDayMissed[key] = (byDayMissed[key] ?? 0) + 1;
    }
    final rates = <Map<String, dynamic>>[];
    for (final e in byDay.entries) {
      final missed = byDayMissed[e.key] ?? 0;
      final taken = e.value - missed;
      rates.add({
        'date': e.key,
        'rate': e.value > 0 ? (taken / e.value * 100).round() : 0,
        'total': e.value,
      });
    }
    rates.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    final overall = byDay.values.fold<int>(0, (s, v) => s + v);
    final overallTaken =
        overall - byDayMissed.values.fold<int>(0, (s, v) => s + v);
    final overallPct = overall > 0 ? (overallTaken / overall * 100).round() : 0;

    final cs = Theme.of(context).colorScheme;

    return HcPanel(
      title: 'Medication adherence',
      subtitle:
          '$overallPct% · $overall doses · ${flDateLabel(filter, from, to)}',
      icon: Icons.show_chart_rounded,
      color: hcTeal,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Date chips — scrollable row, never overflows
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          child: Row(children: [
            for (final f in const [
              ('today', 'Today'),
              ('yesterday', 'Yesterday'),
              ('7d', '7 days'),
              ('30d', '30 days'),
              ('year', 'Year'),
              ('custom', 'Custom'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: filter == f.$1,
                  label: Text(f.$2,
                      style: const TextStyle(fontSize: 11.5)),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) =>
                      ref.read(_dashDoseFilter.notifier).state = f.$1,
                ),
              ),
          ]),
        ),
        if (filter == 'custom') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _DateField(
                    label: 'From',
                    value: from,
                    onChanged: (v) =>
                        ref.read(_dashDoseFrom.notifier).state = v,
                    onPick: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate:
                            DateTime.now().add(const Duration(days: 2)),
                        initialDate: DateTime.now()
                            .subtract(const Duration(days: 7)),
                      );
                      if (d != null) {
                        ref.read(_dashDoseFrom.notifier).state =
                            DateFormat('yyyy-MM-dd').format(d);
                      }
                    })),
            const SizedBox(width: 8),
            Expanded(
                child: _DateField(
                    label: 'To',
                    value: to,
                    onChanged: (v) =>
                        ref.read(_dashDoseTo.notifier).state = v,
                    onPick: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate:
                            DateTime.now().add(const Duration(days: 2)),
                        initialDate: DateTime.now(),
                      );
                      if (d != null) {
                        ref.read(_dashDoseTo.notifier).state =
                            DateFormat('yyyy-MM-dd').format(d);
                      }
                    })),
          ]),
        ],
        const SizedBox(height: 12),
        // Summary row
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: hcTeal.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14)),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Mini(label: 'Pending', value: '${rates.fold<int>(0, (s, r) => s + ((r['total'] as int) - ((r['total'] as int) - (r['rate'] as int) * (r['total'] as int) ~/ 100)))}', color: hcAmber),
                _Mini(label: 'Adherence', value: '$overallPct%', color: overallPct >= 70 ? hcGreen : hcRed),
                _Mini(label: 'Doses', value: '$overall', color: hcSlate),
              ]),
        ),
        const SizedBox(height: 14),
        doses.maybeWhen(
          loading: () => const _ChartLoading(),
          orElse: () => rates.length < 2
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Need at least 2 days of data for a chart.')))
              : SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 100,
                      gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 25,
                          getDrawingHorizontalLine: (v) => FlLine(
                              color: cs.outlineVariant, strokeWidth: 0.7)),
                      borderData: FlBorderData(
                          show: true,
                          border: Border.all(
                              color: cs.outlineVariant, width: 0.7)),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: 20,
                            getTitlesWidget: (v, _) => Text(
                                '${v.round()}%',
                                style: const TextStyle(fontSize: 11)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: (rates.length / 3)
                                .ceil()
                                .toDouble()
                                .clamp(1, 100),
                            getTitlesWidget: (v, _) {
                              final i = v.round();
                              if (i < 0 || i >= rates.length) {
                                return const SizedBox.shrink();
                              }
                              final date = DateTime.tryParse(
                                  rates[i]['date'].toString());
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                    date != null
                                        ? DateFormat('d MMM').format(date)
                                        : '',
                                    style: const TextStyle(fontSize: 10)),
                              );
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          color: hcTeal,
                          barWidth: 2.8,
                          dotData: FlDotData(
                              show: true,
                              getDotPainter: (s, _, __, ___) =>
                                  FlDotCirclePainter(
                                      radius: 3,
                                      color: Colors.white,
                                      strokeWidth: 2.2,
                                      strokeColor: hcTeal)),
                          belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    hcTeal.withValues(alpha: 0.18),
                                    hcTeal.withValues(alpha: 0.0),
                                  ])),
                          spots: [
                            for (var i = 0; i < rates.length; i++)
                              FlSpot(
                                  i.toDouble(),
                                  ((rates[i]['rate'] as num?) ?? 0)
                                      .toDouble()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ]),
    );
  }
}

class _ChartLoading extends StatelessWidget {
  const _ChartLoading();
  @override
  Widget build(BuildContext context) {
    return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()));
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onPick;
  const _DateField(
      {required this.label,
      required this.value,
      required this.onChanged,
      required this.onPick});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: value),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_today, size: 18),
            onPressed: onPick),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Mini(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      Text(label,
          style: const TextStyle(fontSize: 11),
          overflow: TextOverflow.ellipsis),
    ]);
  }
}

// ── flDateLabel defined before panels that use it ──
String flDateLabel(String filter, String from, String to) {
  switch (filter) {
    case 'today':
      return DateFormat('d MMM').format(DateTime.now());
    case 'yesterday':
      return DateFormat('d MMM')
          .format(DateTime.now().subtract(const Duration(days: 1)));
    case '7d':
      final s = DateTime.now().subtract(const Duration(days: 6));
      return '${DateFormat('d MMM').format(s)} – ${DateFormat('d MMM').format(DateTime.now())}';
    case '30d':
      final s = DateTime.now().subtract(const Duration(days: 29));
      return '${DateFormat('d MMM').format(s)} – ${DateFormat('d MMM').format(DateTime.now())}';
    case 'year':
      final s = DateTime.now().subtract(const Duration(days: 365));
      return '${DateFormat('d MMM y').format(s)} – ${DateFormat('d MMM y').format(DateTime.now())}';
    case 'custom':
      if (from.isNotEmpty && to.isNotEmpty) {
        return '$from – $to';
      }
      return 'Pick a date range';
    default:
      return '';
  }
}

class _FilteredDosesPanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doses = ref.watch(_dashDosesProvider);

    return HcPanel(
      title: 'Dose tracking',
      subtitle: 'Administration log for the selected range',
      icon: Icons.medication_liquid_rounded,
      color: hcBlue,
      action: TextButton(
          onPressed: () => context.go('/homecare/doses'),
          child: const Text('All doses')),
      child: doses.maybeWhen(
        loading: () => const _ChartLoading(),
        data: (list) {
          final rows = list.cast<Map>().toList()
            ..sort((a, b) => (b['scheduled_at'] ?? '')
                .toString()
                .compareTo((a['scheduled_at'] ?? '').toString()));
          if (rows.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No doses in this range.')),
            );
          }
          final pending =
              rows.where((d) => d['status'] == 'pending').length;
          final taken = rows.where((d) => d['status'] == 'taken').length;
          final missed = rows.where((d) => d['status'] == 'missed').length;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Mini(
                          label: 'Pending',
                          value: '$pending',
                          color: hcAmber),
                      _Mini(
                          label: 'Taken',
                          value: '$taken',
                          color: hcGreen),
                      _Mini(
                          label: 'Missed',
                          value: '$missed',
                          color: hcRed),
                      _Mini(
                          label: 'Total',
                          value: '${rows.length}',
                          color: hcSlate),
                    ]),
                const SizedBox(height: 10),
                ...rows.take(25).map((d) {
                  final status = d['status']?.toString() ?? '';
                  final color = hcDoseStatusColor(status);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Container(
                        width: 4,
                        height: 36,
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  (d['medication_name'] ?? '—')
                                      .toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5)),
                              Text(
                                  '${d['patient_name'] ?? ''} · ${hcTime(d['scheduled_at'])}',
                                  style: const TextStyle(
                                      fontSize: 11, color: hcSlate)),
                            ]),
                      ),
                      HcStatusChip(
                          label: hcLabel(status), color: color),
                    ]),
                  );
                }),
              ]);
        },
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }
}
