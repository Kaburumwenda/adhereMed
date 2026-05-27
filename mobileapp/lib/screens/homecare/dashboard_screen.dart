import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme_provider.dart';
import '../../widgets/common.dart';
import 'providers.dart';

class HomecareDashboardScreen extends ConsumerWidget {
  const HomecareDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(homecareDashboardProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(homecareDashboardProvider),
      child: dash.when(
        loading: () => const LoadingShimmer(lines: 8),
        error: (e, _) => ErrorRetry(
          message: 'Failed to load dashboard',
          onRetry: () => ref.invalidate(homecareDashboardProvider),
        ),
        data: (data) {
          final kpis = data['kpis'] as Map<String, dynamic>? ?? {};
          final todayDoses = data['today_doses'] as Map<String, dynamic>? ?? {};
          final trend = (data['adherence_trend'] as List?) ?? [];
          final visits = (data['upcoming_visits'] as List?) ?? [];
          final escalations = (data['recent_escalations'] as List?) ?? [];

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              // ── Hero Header ──
              _HeroHeader(kpis: kpis, isDark: isDark, cs: cs),

              // ── KPI Strip (horizontal scroll) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text('Overview', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _KpiChip(icon: Icons.people_alt_rounded, label: 'Patients', value: '${kpis['active_patients'] ?? 0}', color: const Color(0xFF0D9488)),
                    _KpiChip(icon: Icons.medical_services_rounded, label: 'On Duty', value: '${kpis['caregivers_on_duty'] ?? 0}/${kpis['caregivers_total'] ?? 0}', color: const Color(0xFF6366F1)),
                    _KpiChip(icon: Icons.medication_rounded, label: 'Adherence', value: kpis['adherence_today'] != null ? '${kpis['adherence_today']}%' : '—', color: const Color(0xFF10B981)),
                    _KpiChip(icon: Icons.warning_amber_rounded, label: 'Escalations', value: '${kpis['open_escalations'] ?? 0}', color: const Color(0xFFEF4444)),
                    _KpiChip(icon: Icons.shield_rounded, label: 'Claims', value: '${kpis['open_claims'] ?? 0}', color: const Color(0xFFF59E0B)),
                  ],
                ),
              ),

              // ── Today's Doses ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _DoseSummaryCard(doses: todayDoses, cs: cs),
              ),

              // ── Adherence Trend Chart ──
              if (trend.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _AdherenceChart(trend: trend, cs: cs, isDark: isDark),
                ),

              // ── Caregiver Workforce Stats ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _WorkforceCard(kpis: kpis, cs: cs),
              ),

              // ── Quick Actions Grid ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _QuickActionsGrid(cs: cs),
              ),

              // ── Upcoming Visits ──
              if (visits.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: _VisitsCard(visits: visits, cs: cs),
                ),

              // ── Recent Escalations ──
              if (escalations.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _EscalationsCard(escalations: escalations, cs: cs),
                ),

              const SizedBox(height: 100),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Hero Header
// ═══════════════════════════════════════════════════════════
class _HeroHeader extends ConsumerWidget {
  final Map<String, dynamic> kpis;
  final bool isDark;
  final ColorScheme cs;

  const _HeroHeader({required this.kpis, required this.isDark, required this.cs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateFormat('EEEE, MMM d').format(DateTime.now());
    final time = DateFormat('h:mm a').format(DateTime.now());
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)]
              : [const Color(0xFF0D9488), const Color(0xFF0EA5E9)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOMECARE COMMAND CENTRE',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Welcome back',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Live operations · ${kpis['active_patients'] ?? 0} patients in care',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _HeroChip(icon: Icons.schedule_rounded, label: time),
              _HeroChip(icon: Icons.calendar_today_rounded, label: now),
              _HeroChip(icon: Icons.favorite_rounded, label: '${kpis['caregivers_on_duty'] ?? 0} on duty'),
              _HeroChip(icon: Icons.medication_rounded, label: '${kpis['adherence_today'] ?? 0}% adherence'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// KPI Chip (horizontal scroll item)
// ═══════════════════════════════════════════════════════════
class _KpiChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _KpiChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
              Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Dose Summary Card with donut
// ═══════════════════════════════════════════════════════════
class _DoseSummaryCard extends StatelessWidget {
  final Map<String, dynamic> doses;
  final ColorScheme cs;

  const _DoseSummaryCard({required this.doses, required this.cs});

  @override
  Widget build(BuildContext context) {
    final total = (doses['total'] as num?)?.toInt() ?? 0;
    final taken = (doses['taken'] as num?)?.toInt() ?? 0;
    final missed = (doses['missed'] as num?)?.toInt() ?? 0;
    final pending = (doses['pending'] as num?)?.toInt() ?? 0;
    final skipped = (doses['skipped'] as num?)?.toInt() ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF0EA5E9CC)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.medication_liquid_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's Doses", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text('Live medication tracking', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
                  child: Text('$total total', style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: total > 0
                      ? PieChart(PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 32,
                          sections: [
                            if (taken > 0) PieChartSectionData(value: taken.toDouble(), color: Colors.green, radius: 20, showTitle: false),
                            if (pending > 0) PieChartSectionData(value: pending.toDouble(), color: Colors.orange, radius: 20, showTitle: false),
                            if (missed > 0) PieChartSectionData(value: missed.toDouble(), color: Colors.red, radius: 20, showTitle: false),
                            if (skipped > 0) PieChartSectionData(value: skipped.toDouble(), color: Colors.grey, radius: 20, showTitle: false),
                          ],
                        ))
                      : Center(child: Text('No data', style: TextStyle(color: cs.onSurfaceVariant))),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      _DoseLegendRow(label: 'Taken', count: taken, color: Colors.green),
                      _DoseLegendRow(label: 'Pending', count: pending, color: Colors.orange),
                      _DoseLegendRow(label: 'Missed', count: missed, color: Colors.red),
                      _DoseLegendRow(label: 'Skipped', count: skipped, color: Colors.grey),
                    ],
                  ),
                ),
              ],
            ),
            if (total > 0) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: taken / total,
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(taken * 100 ~/ total)}% administered',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DoseLegendRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _DoseLegendRow({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text('$count', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Adherence Trend Chart (Bar chart like web)
// ═══════════════════════════════════════════════════════════
class _AdherenceChart extends StatelessWidget {
  final List trend;
  final ColorScheme cs;
  final bool isDark;

  const _AdherenceChart({required this.trend, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final rates = trend.map((t) => (t['rate'] as num?)?.toDouble() ?? 0.0).toList();
    final avg = rates.isNotEmpty ? (rates.reduce((a, b) => a + b) / rates.length).round() : 0;
    final best = rates.isNotEmpty ? rates.reduce((a, b) => a > b ? a : b).round() : 0;
    final worst = rates.isNotEmpty ? rates.reduce((a, b) => a < b ? a : b).round() : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF0D9488CC)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.show_chart_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('7-Day Adherence', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text('Doses taken on time', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (v) => FlLine(color: cs.outlineVariant.withValues(alpha: 0.3), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 25,
                        getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= trend.length) return const SizedBox();
                          final date = DateTime.tryParse(trend[i]['date'] ?? '');
                          if (date == null) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(DateFormat('E').format(date), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  maxY: 100,
                  barGroups: List.generate(trend.length, (i) {
                    final rate = (trend[i]['rate'] as num?)?.toDouble() ?? 0;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: rate,
                          width: 20,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [cs.primary.withValues(alpha: 0.6), cs.primary],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChipSmall(label: 'Avg', value: '$avg%', color: Colors.green),
                const SizedBox(width: 8),
                _StatChipSmall(label: 'Best', value: '$best%', color: Colors.blue),
                const SizedBox(width: 8),
                _StatChipSmall(label: 'Worst', value: '$worst%', color: Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChipSmall extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChipSmall({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Workforce Card
// ═══════════════════════════════════════════════════════════
class _WorkforceCard extends StatelessWidget {
  final Map<String, dynamic> kpis;
  final ColorScheme cs;

  const _WorkforceCard({required this.kpis, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF6366F1CC)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.groups_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Caregiver Workforce', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text('Field team status', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/homecare/caregivers'),
                  child: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _WorkforceStat(label: 'On Duty', value: '${kpis['caregivers_on_duty'] ?? 0}', color: Colors.teal)),
                const SizedBox(width: 8),
                Expanded(child: _WorkforceStat(label: 'Total', value: '${kpis['caregivers_total'] ?? 0}', color: cs.primary)),
                const SizedBox(width: 8),
                Expanded(child: _WorkforceStat(label: 'Visits', value: '${kpis['visits_completed_today'] ?? 0}', color: Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _WorkforceStat(label: 'Rating', value: '${kpis['avg_rating'] ?? '—'}', color: Colors.amber.shade700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkforceStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _WorkforceStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Quick Actions Grid (12 actions matching web)
// ═══════════════════════════════════════════════════════════
class _QuickActionsGrid extends StatelessWidget {
  final ColorScheme cs;
  const _QuickActionsGrid({required this.cs});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QA(icon: Icons.person_add_rounded, label: 'Enrol Patient', path: '/homecare/patients/new', color: const Color(0xFF0D9488)),
      _QA(icon: Icons.calendar_month_rounded, label: 'Schedule Visit', path: '/homecare/schedules', color: const Color(0xFF6366F1)),
      _QA(icon: Icons.medication_rounded, label: "Today's Doses", path: '/homecare/my-day', color: const Color(0xFF10B981)),
      _QA(icon: Icons.groups_rounded, label: 'Caregivers', path: '/homecare/caregivers', color: const Color(0xFF0EA5E9)),
      _QA(icon: Icons.warning_amber_rounded, label: 'Escalations', path: '/homecare/escalations', color: const Color(0xFFEF4444)),
      _QA(icon: Icons.description_rounded, label: 'Prescriptions', path: '/homecare/patients', color: const Color(0xFF8B5CF6)),
      _QA(icon: Icons.shield_rounded, label: 'Insurance', path: '/homecare/patients', color: const Color(0xFFF59E0B)),
      _QA(icon: Icons.monitor_heart_rounded, label: 'Vitals', path: '/homecare/patients', color: const Color(0xFFEF4444)),
      _QA(icon: Icons.account_tree_rounded, label: 'Assignments', path: '/homecare/assignments', color: const Color(0xFF0D9488)),
      _QA(icon: Icons.receipt_long_rounded, label: 'Billing', path: '/homecare/patients', color: const Color(0xFF0284C7)),
      _QA(icon: Icons.devices_rounded, label: 'Equipment', path: '/homecare/patients', color: const Color(0xFF7C3AED)),
      _QA(icon: Icons.analytics_rounded, label: 'Reports', path: '/homecare/patients', color: const Color(0xFF475569)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.flash_on_rounded, color: cs.primary, size: 18),
            const SizedBox(width: 6),
            Text('Quick Actions', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: actions.length,
          itemBuilder: (_, i) {
            final a = actions[i];
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.push(a.path),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: a.color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: a.color.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [a.color, a.color.withValues(alpha: 0.7)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(a.icon, color: Colors.white, size: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      a.label,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: a.color),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _QA {
  final IconData icon;
  final String label;
  final String path;
  final Color color;
  const _QA({required this.icon, required this.label, required this.path, required this.color});
}

// ═══════════════════════════════════════════════════════════
// Visits Card
// ═══════════════════════════════════════════════════════════
class _VisitsCard extends StatelessWidget {
  final List visits;
  final ColorScheme cs;

  const _VisitsCard({required this.visits, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF0D9488CC)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Upcoming Visits', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text('Next caregiver shifts', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/homecare/schedules'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...visits.take(5).map((v) => _VisitRow(visit: v, cs: cs)),
          ],
        ),
      ),
    );
  }
}

class _VisitRow extends StatelessWidget {
  final dynamic visit;
  final ColorScheme cs;
  const _VisitRow({required this.visit, required this.cs});

  @override
  Widget build(BuildContext context) {
    final status = visit['status'] ?? '';
    final patientName = visit['patient_name'] ?? visit['patient']?['user']?['full_name'] ?? 'Unknown';
    final caregiverName = visit['caregiver_name'] ?? visit['caregiver']?['user']?['full_name'] ?? '';
    final startAt = DateTime.tryParse(visit['start_at'] ?? '');
    final timeStr = startAt != null ? DateFormat('h:mm a').format(startAt.toLocal()) : '';

    final Color statusColor;
    switch (status) {
      case 'scheduled':
        statusColor = Colors.blue;
      case 'checked_in':
        statusColor = Colors.green;
      case 'completed':
        statusColor = Colors.grey;
      case 'missed':
        statusColor = Colors.red;
      default:
        statusColor = cs.onSurfaceVariant;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.teal.withValues(alpha: 0.1),
            child: Text(
              timeStr.isNotEmpty ? timeStr.split(':')[0] : '?',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.teal),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patientName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (caregiverName.isNotEmpty)
                  Text(caregiverName, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(status.replaceAll('_', ' '), style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Escalations Card
// ═══════════════════════════════════════════════════════════
class _EscalationsCard extends StatelessWidget {
  final List escalations;
  final ColorScheme cs;

  const _EscalationsCard({required this.escalations, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFEF4444CC)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.warning_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Open Escalations', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text('Patients flagged for review', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/homecare/escalations'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...escalations.take(5).map((e) => _EscalationRow(esc: e, cs: cs)),
          ],
        ),
      ),
    );
  }
}

class _EscalationRow extends StatelessWidget {
  final dynamic esc;
  final ColorScheme cs;
  const _EscalationRow({required this.esc, required this.cs});

  @override
  Widget build(BuildContext context) {
    final severity = esc['severity'] ?? 'medium';
    final reason = esc['reason'] ?? '';
    final patientName = esc['patient_name'] ?? esc['patient']?['user']?['full_name'] ?? 'Unknown';
    final triggeredAt = DateTime.tryParse(esc['triggered_at'] ?? '');
    final timeAgo = triggeredAt != null ? _formatRelative(triggeredAt) : '';

    final Color sevColor;
    switch (severity) {
      case 'critical':
        sevColor = Colors.red.shade700;
      case 'high':
        sevColor = Colors.orange.shade700;
      case 'medium':
        sevColor = Colors.amber.shade700;
      default:
        sevColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: sevColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sevColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: sevColor.withValues(alpha: 0.12),
            child: Icon(Icons.warning_amber_rounded, color: sevColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reason, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('$patientName · $timeAgo', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: sevColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(severity, style: TextStyle(fontSize: 10, color: sevColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
