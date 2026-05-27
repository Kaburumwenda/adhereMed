import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/common.dart';
import 'providers.dart';

class HomecareSchedulesScreen extends ConsumerStatefulWidget {
  const HomecareSchedulesScreen({super.key});

  @override
  ConsumerState<HomecareSchedulesScreen> createState() => _HomecareSchedulesScreenState();
}

class _HomecareSchedulesScreenState extends ConsumerState<HomecareSchedulesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _statusFilters = ['', 'scheduled', 'checked_in', 'completed', 'missed', 'cancelled'];
  final _statusLabels = ['All', 'Scheduled', 'In Progress', 'Completed', 'Missed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusFilters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(homecareScheduleStatusFilter.notifier).state = _statusFilters[_tabController.index];
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schedules = ref.watch(homecareSchedulesProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedules & Visits'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _statusLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: schedules.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorRetry(
          message: 'Failed to load schedules',
          onRetry: () => ref.invalidate(homecareSchedulesProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.calendar_today_rounded,
              title: 'No visits found',
              subtitle: 'Scheduled visits will appear here',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(homecareSchedulesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) => _ScheduleCard(schedule: list[i], cs: cs)
                  .animate(delay: Duration(milliseconds: 40 * i))
                  .fadeIn(duration: 250.ms)
                  .slideY(begin: 0.05, duration: 250.ms),
            ),
          );
        },
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final dynamic schedule;
  final ColorScheme cs;

  const _ScheduleCard({required this.schedule, required this.cs});

  @override
  Widget build(BuildContext context) {
    final status = schedule['status'] ?? '';
    final shiftType = schedule['shift_type'] ?? 'visit';
    final patientName = schedule['patient_name'] ?? schedule['patient']?['user']?['full_name'] ?? 'Unknown';
    final caregiverName = schedule['caregiver_name'] ?? schedule['caregiver']?['user']?['full_name'] ?? '';
    final startAt = DateTime.tryParse(schedule['start_at'] ?? '');
    final endAt = DateTime.tryParse(schedule['end_at'] ?? '');
    final notes = schedule['notes'] ?? '';

    final statusColor = switch (status) {
      'scheduled' => Colors.blue,
      'checked_in' => Colors.green,
      'completed' => Colors.grey,
      'missed' => Colors.red,
      'cancelled' => Colors.grey.shade500,
      _ => cs.onSurfaceVariant,
    };

    final statusIcon = switch (status) {
      'scheduled' => Icons.schedule_rounded,
      'checked_in' => Icons.login_rounded,
      'completed' => Icons.check_circle_rounded,
      'missed' => Icons.cancel_rounded,
      'cancelled' => Icons.block_rounded,
      _ => Icons.circle_outlined,
    };

    final shiftIcon = switch (shiftType) {
      'live_in' => Icons.home_rounded,
      'on_call' => Icons.phone_callback_rounded,
      _ => Icons.directions_walk_rounded,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      if (caregiverName.isNotEmpty)
                        Text(
                          caregiverName,
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
                    status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Time and shift info
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    startAt != null ? DateFormat('MMM d, h:mm a').format(startAt.toLocal()) : 'N/A',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface),
                  ),
                  if (endAt != null) ...[
                    Text(' → ', style: TextStyle(color: cs.onSurfaceVariant)),
                    Text(
                      DateFormat('h:mm a').format(endAt.toLocal()),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface),
                    ),
                  ],
                  const Spacer(),
                  Icon(shiftIcon, size: 16, color: cs.primary),
                  const SizedBox(width: 4),
                  Text(
                    shiftType.replaceAll('_', ' '),
                    style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                notes,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
