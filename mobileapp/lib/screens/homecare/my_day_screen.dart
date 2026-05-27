import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/api.dart';
import '../../widgets/common.dart';
import 'providers.dart';

class HomecareMyDayScreen extends ConsumerWidget {
  const HomecareMyDayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myDay = ref.watch(homecareMyDayProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('My Day')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(homecareMyDayProvider),
        child: myDay.when(
          loading: () => const LoadingShimmer(lines: 6),
          error: (e, _) => ErrorRetry(
            message: 'Failed to load your schedule',
            onRetry: () => ref.invalidate(homecareMyDayProvider),
          ),
          data: (data) {
            final caregiver = data['caregiver'] as Map<String, dynamic>? ?? {};
            final visits = (data['visits'] as List?) ?? [];
            final doses = (data['doses'] as List?) ?? [];
            final name = caregiver['user']?['full_name'] ?? '';

            return CustomScrollView(
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                            : [cs.primary, cs.primary.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          child: const Icon(Icons.waving_hand_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello, ${name.split(' ').first}!',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                DateFormat('EEEE, MMM d').format(DateTime.now()),
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text('${visits.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                              Text('visits', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                ),
                // Visits Section
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: "Today's Visits",
                    trailing: Text('${visits.length} total', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ),
                ),
                if (visits.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: EmptyState(icon: Icons.event_available_rounded, title: 'No visits today'),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _MyVisitCard(visit: visits[i], cs: cs, ref: ref, index: i),
                      childCount: visits.length,
                    ),
                  ),
                // Doses Section
                SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Medication Doses',
                    trailing: Text('${doses.length} total', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ),
                ),
                if (doses.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: EmptyState(icon: Icons.medication_rounded, title: 'No doses scheduled'),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _DoseCard(dose: doses[i], cs: cs, ref: ref),
                      childCount: doses.length,
                    ),
                  ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MyVisitCard extends StatelessWidget {
  final dynamic visit;
  final ColorScheme cs;
  final WidgetRef ref;
  final int index;

  const _MyVisitCard({required this.visit, required this.cs, required this.ref, required this.index});

  @override
  Widget build(BuildContext context) {
    final status = visit['status'] ?? 'scheduled';
    final patientName = visit['patient_name'] ?? visit['patient']?['user']?['full_name'] ?? 'Unknown';
    final startAt = DateTime.tryParse(visit['start_at'] ?? '');
    final endAt = DateTime.tryParse(visit['end_at'] ?? '');
    final statusColor = switch (status) {
      'scheduled' => Colors.blue,
      'checked_in' => Colors.green,
      'completed' => Colors.grey,
      'missed' => Colors.red,
      _ => cs.onSurfaceVariant,
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.person_pin_circle_rounded, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patientName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(
                        '${startAt != null ? DateFormat('h:mm a').format(startAt.toLocal()) : ''}'
                        '${endAt != null ? ' - ${DateFormat('h:mm a').format(endAt.toLocal())}' : ''}',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.replaceAll('_', ' '),
                    style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (status == 'scheduled') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _checkIn(context, visit['id']),
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: const Text('Check In'),
                ),
              ),
            ],
            if (status == 'checked_in') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => _checkOut(context, visit['id']),
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Check Out'),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: 60 * index)).fadeIn(duration: 300.ms).slideX(begin: 0.05);

  }

  Future<void> _checkIn(BuildContext context, dynamic id) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/homecare/schedules/$id/', data: {'status': 'checked_in'});
      ref.invalidate(homecareMyDayProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked in successfully'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check-in failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _checkOut(BuildContext context, dynamic id) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/homecare/schedules/$id/', data: {'status': 'completed'});
      ref.invalidate(homecareMyDayProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked out successfully'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Check-out failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}

class _DoseCard extends StatelessWidget {
  final dynamic dose;
  final ColorScheme cs;
  final WidgetRef ref;

  const _DoseCard({required this.dose, required this.cs, required this.ref});

  @override
  Widget build(BuildContext context) {
    final status = dose['status'] ?? 'pending';
    final scheduledAt = DateTime.tryParse(dose['scheduled_at'] ?? '');
    final medName = dose['schedule']?['medication_name'] ?? dose['medication_name'] ?? 'Medication';
    final doseStr = dose['schedule']?['dose'] ?? dose['dose'] ?? '';
    final patientName = dose['schedule']?['patient']?['user']?['full_name'] ?? '';

    final statusColor = switch (status) {
      'taken' => Colors.green,
      'missed' => Colors.red,
      'pending' => Colors.orange,
      'skipped' => Colors.grey,
      _ => cs.onSurfaceVariant,
    };

    final statusIcon = switch (status) {
      'taken' => Icons.check_circle_rounded,
      'missed' => Icons.cancel_rounded,
      'pending' => Icons.access_time_rounded,
      'skipped' => Icons.skip_next_rounded,
      _ => Icons.circle_outlined,
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Text(medName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${doseStr.isNotEmpty ? '$doseStr • ' : ''}'
          '${scheduledAt != null ? DateFormat('h:mm a').format(scheduledAt.toLocal()) : ''}'
          '${patientName.isNotEmpty ? ' • $patientName' : ''}',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        trailing: status == 'pending'
            ? IconButton(
                icon: const Icon(Icons.check_rounded, color: Colors.green),
                onPressed: () => _markTaken(context, dose['id']),
              )
            : null,
      ),
    );
  }

  Future<void> _markTaken(BuildContext context, dynamic id) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/homecare/doses/$id/', data: {'status': 'taken'});
      ref.invalidate(homecareMyDayProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dose marked as taken'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}
