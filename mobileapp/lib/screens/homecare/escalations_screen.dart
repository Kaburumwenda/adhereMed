import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/api.dart';
import '../../widgets/common.dart';
import 'providers.dart';

class HomecareEscalationsScreen extends ConsumerStatefulWidget {
  const HomecareEscalationsScreen({super.key});

  @override
  ConsumerState<HomecareEscalationsScreen> createState() => _HomecareEscalationsScreenState();
}

class _HomecareEscalationsScreenState extends ConsumerState<HomecareEscalationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _filters = ['open', 'acknowledged', 'resolved', ''];
  final _labels = ['Open', 'Acknowledged', 'Resolved', 'All'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(homecareEscalationStatusFilter.notifier).state = _filters[_tabController.index];
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
    final escalations = ref.watch(homecareEscalationsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escalations'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _labels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: escalations.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorRetry(
          message: 'Failed to load escalations',
          onRetry: () => ref.invalidate(homecareEscalationsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'No escalations',
              subtitle: 'All clear — no escalations to show',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(homecareEscalationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) => _EscalationCard(escalation: list[i], cs: cs, ref: ref)
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

class _EscalationCard extends StatelessWidget {
  final dynamic escalation;
  final ColorScheme cs;
  final WidgetRef ref;

  const _EscalationCard({required this.escalation, required this.cs, required this.ref});

  @override
  Widget build(BuildContext context) {
    final severity = escalation['severity'] ?? 'medium';
    final status = escalation['status'] ?? 'open';
    final reason = escalation['reason'] ?? '';
    final detail = escalation['detail'] ?? '';
    final patientName = escalation['patient_name'] ?? escalation['patient']?['user']?['full_name'] ?? 'Unknown';
    final triggeredAt = DateTime.tryParse(escalation['triggered_at'] ?? '');
    final resolvedAt = DateTime.tryParse(escalation['resolved_at'] ?? '');

    final sevColor = switch (severity) {
      'critical' => Colors.red.shade700,
      'high' => Colors.orange.shade700,
      'medium' => Colors.amber.shade700,
      _ => Colors.green,
    };

    final statusColor = switch (status) {
      'open' => Colors.red,
      'acknowledged' => Colors.blue,
      'resolved' => Colors.green,
      _ => cs.onSurfaceVariant,
    };

    final sevIcon = switch (severity) {
      'critical' => Icons.error_rounded,
      'high' => Icons.warning_rounded,
      'medium' => Icons.warning_amber_rounded,
      _ => Icons.info_outline_rounded,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: sevColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(sevIcon, color: sevColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reason, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(patientName, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: sevColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        severity.toUpperCase(),
                        style: TextStyle(fontSize: 10, color: sevColor, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(detail, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant), maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 10),
            // Footer with time info
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    triggeredAt != null ? DateFormat('MMM d, h:mm a').format(triggeredAt.toLocal()) : 'Unknown',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  if (resolvedAt != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, h:mm a').format(resolvedAt.toLocal()),
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                ],
              ),
            ),
            // Actions for open escalations
            if (status == 'open') ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _acknowledgeEscalation(context, escalation['id']),
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: const Text('Acknowledge'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _resolveEscalation(context, escalation['id']),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Resolve'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _acknowledgeEscalation(BuildContext context, dynamic id) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/homecare/escalations/$id/', data: {'status': 'acknowledged'});
      ref.invalidate(homecareEscalationsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escalation acknowledged'), behavior: SnackBarBehavior.floating),
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

  Future<void> _resolveEscalation(BuildContext context, dynamic id) async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve Escalation'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(hintText: 'Resolution notes (optional)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Resolve')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dio = ref.read(dioProvider);
        await dio.patch('/homecare/escalations/$id/', data: {
          'status': 'resolved',
          'resolution_notes': notesController.text,
        });
        ref.invalidate(homecareEscalationsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Escalation resolved'), behavior: SnackBarBehavior.floating),
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
    notesController.dispose();
  }
}
