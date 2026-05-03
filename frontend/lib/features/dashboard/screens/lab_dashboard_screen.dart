import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

// ---------------------------------------------------------------------------
// Data provider
// ---------------------------------------------------------------------------

final _labDashboardProvider =
    FutureProvider.autoDispose<_LabDashboardData>((ref) async {
  final dio = ApiClient.instance;

  final results = await Future.wait<dynamic>([
    // 0 – dashboard stats
    dio
        .get('/exchange/lab/dashboard/')
        .then((r) => r.data as Map<String, dynamic>)
        .catchError((_) => <String, dynamic>{}),
    // 1 – recent pending requests
    dio
        .get('/exchange/lab/', queryParameters: {'status': 'pending', 'page_size': 5})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
    // 2 – my active orders (accepted/processing/sample_collected)
    dio
        .get('/exchange/lab/', queryParameters: {'status': 'accepted', 'page_size': 10})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
    // 3 – completed orders
    dio
        .get('/exchange/lab/', queryParameters: {'status': 'completed', 'page_size': 5})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
  ]);

  return _LabDashboardData(
    stats: results[0] as Map<String, dynamic>,
    pendingRequests: results[1] as Map<String, dynamic>,
    activeOrders: results[2] as Map<String, dynamic>,
    completedOrders: results[3] as Map<String, dynamic>,
  );
});

class _LabDashboardData {
  final Map<String, dynamic> stats;
  final Map<String, dynamic> pendingRequests;
  final Map<String, dynamic> activeOrders;
  final Map<String, dynamic> completedOrders;

  _LabDashboardData({
    required this.stats,
    required this.pendingRequests,
    required this.activeOrders,
    required this.completedOrders,
  });
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class LabDashboardScreen extends ConsumerWidget {
  const LabDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final dashAsync = ref.watch(_labDashboardProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.tenantName ?? 'Lab Dashboard',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Welcome back, ${user?.firstName ?? 'Lab Tech'} — here\'s your overview',
                      style:
                          TextStyle(color: AppColors.textSecondary, fontSize: 15),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(_labDashboardProvider),
              ),
            ],
          ),
          const SizedBox(height: 24),

          dashAsync.when(
            loading: () => const Center(child: LoadingWidget()),
            error: (e, _) => _buildFallbackDashboard(context),
            data: (data) => _buildLiveDashboard(context, ref, data),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (ctx, c) {
          final cross = c.maxWidth > 900 ? 4 : c.maxWidth > 600 ? 2 : 1;
          final w = (c.maxWidth - (cross - 1) * 16) / cross;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.pending_actions,
                      title: 'Pending Requests',
                      value: '--',
                      color: AppColors.warning)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.science,
                      title: 'In Progress',
                      value: '--',
                      color: AppColors.primary)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.check_circle,
                      title: 'Completed Today',
                      value: '--',
                      color: AppColors.success)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.priority_high,
                      title: 'Urgent',
                      value: '--',
                      color: AppColors.error)),
            ],
          );
        }),
        const SizedBox(height: 24),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
                'Could not load dashboard data. Check your connection and try again.'),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveDashboard(
      BuildContext context, WidgetRef ref, _LabDashboardData data) {
    final stats = data.stats;
    final pendingCount = stats['pending_requests'] ?? 0;
    final acceptedCount = stats['accepted_orders'] ?? 0;
    final processingCount = stats['processing'] ?? 0;
    final sampleCollected = stats['sample_collected'] ?? 0;
    final completedToday = stats['completed_today'] ?? 0;
    final completedTotal = stats['completed_total'] ?? 0;
    final urgentCount = stats['urgent_orders'] ?? 0;
    final homeCollections = stats['home_collections'] ?? 0;

    final pendingList =
        data.pendingRequests['results'] as List<dynamic>? ?? [];
    final activeList =
        data.activeOrders['results'] as List<dynamic>? ?? [];
    final completedList =
        data.completedOrders['results'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Row 1: Primary KPIs ──
        Text('Overview',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (ctx, c) {
          final cross = c.maxWidth > 1100
              ? 4
              : c.maxWidth > 700
                  ? 2
                  : 2;
          final w = (c.maxWidth - (cross - 1) * 12) / cross;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.pending_actions,
                      title: 'Pending Requests',
                      value: '$pendingCount',
                      color: AppColors.warning)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.assignment_turned_in,
                      title: 'Accepted',
                      value: '$acceptedCount',
                      color: AppColors.primary)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.hourglass_bottom,
                      title: 'Processing',
                      value: '$processingCount',
                      color: AppColors.secondary)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.colorize,
                      title: 'Sample Collected',
                      value: '$sampleCollected',
                      color: const Color(0xFF8B5CF6))),
            ],
          );
        }),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (ctx, c) {
          final cross = c.maxWidth > 1100
              ? 4
              : c.maxWidth > 700
                  ? 2
                  : 2;
          final w = (c.maxWidth - (cross - 1) * 12) / cross;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.check_circle,
                      title: 'Completed Today',
                      value: '$completedToday',
                      color: AppColors.success)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.done_all,
                      title: 'Total Completed',
                      value: '$completedTotal',
                      color: const Color(0xFF06B6D4))),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.priority_high,
                      title: 'Urgent / STAT',
                      value: '$urgentCount',
                      color: AppColors.error)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.home,
                      title: 'Home Collections',
                      value: '$homeCollections',
                      color: const Color(0xFFF97316))),
            ],
          );
        }),
        const SizedBox(height: 24),

        // ── Quick Actions ──
        Text('Quick Actions',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickAction(
                icon: Icons.pending_actions,
                label: 'Pending Requests',
                color: AppColors.warning,
                onTap: () => context.push('/lab-exchange')),
            _QuickAction(
                icon: Icons.science,
                label: 'Active Orders',
                color: AppColors.primary,
                onTap: () => context.push('/lab-exchange?status=accepted')),
            _QuickAction(
                icon: Icons.biotech,
                label: 'Test Catalog',
                color: AppColors.secondary,
                onTap: () => context.push('/lab-catalog')),
          ],
        ),
        const SizedBox(height: 24),

        // ── Pending Requests Table ──
        LayoutBuilder(builder: (ctx, c) {
          if (c.maxWidth > 1000) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    flex: 3,
                    child:
                        _buildPendingRequests(context, ref, pendingList)),
                const SizedBox(width: 16),
                Expanded(
                    flex: 2,
                    child: _buildActiveOrders(context, activeList)),
              ],
            );
          }
          return Column(
            children: [
              _buildPendingRequests(context, ref, pendingList),
              const SizedBox(height: 16),
              _buildActiveOrders(context, activeList),
            ],
          );
        }),
        const SizedBox(height: 16),

        // ── Recently Completed ──
        _buildCompletedOrders(context, completedList),
      ],
    );
  }

  Widget _buildPendingRequests(
      BuildContext context, WidgetRef ref, List<dynamic> pending) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pending_actions,
                    color: AppColors.warning, size: 20),
                const SizedBox(width: 8),
                Text('Incoming Requests',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/lab-exchange'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (pending.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: Text('No pending requests',
                        style: TextStyle(color: Colors.grey))),
              )
            else
              ...pending.map((req) => _RequestTile(
                    patientName: req['patient_name'] ?? 'Unknown',
                    source: req['source_tenant_name'] ?? 'Unknown',
                    doctor: req['ordering_doctor_name'] ?? '',
                    priority: req['priority'] ?? 'routine',
                    tests: (req['tests'] as List<dynamic>?)
                            ?.map((t) => t['test_name']?.toString() ?? '')
                            .where((t) => t.isNotEmpty)
                            .toList() ??
                        [],
                    onTap: () =>
                        context.push('/lab-exchange/${req['id']}'),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrders(BuildContext context, List<dynamic> orders) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('Active Orders',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            if (orders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: Text('No active orders',
                        style: TextStyle(color: Colors.grey))),
              )
            else
              ...orders.map((order) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primaryLight,
                      child: Icon(Icons.person,
                          size: 18, color: AppColors.primaryDark),
                    ),
                    title: Text(order['patient_name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(order['status']
                            ?.toString()
                            .replaceAll('_', ' ')
                            .toUpperCase() ??
                        ''),
                    trailing: _PriorityBadge(
                        priority: order['priority'] ?? 'routine'),
                    onTap: () =>
                        context.push('/lab-exchange/${order['id']}'),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedOrders(BuildContext context, List<dynamic> orders) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Text('Recently Completed',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            if (orders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: Text('No completed orders yet',
                        style: TextStyle(color: Colors.grey))),
              )
            else
              ...orders.map((order) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFD1FAE5),
                      child:
                          Icon(Icons.check, size: 18, color: Color(0xFF059669)),
                    ),
                    title: Text(order['patient_name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(
                        'From: ${order['source_tenant_name'] ?? 'Unknown'}'),
                    trailing: Text(
                      _formatDate(order['updated_at']),
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    onTap: () =>
                        context.push('/lab-exchange/${order['id']}'),
                  )),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

// ─── Helper widgets ──────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final String patientName;
  final String source;
  final String doctor;
  final String priority;
  final List<String> tests;
  final VoidCallback onTap;

  const _RequestTile({
    required this.patientName,
    required this.source,
    required this.doctor,
    required this.priority,
    required this.tests,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.person, size: 18, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patientName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    'From: $source${doctor.isNotEmpty ? ' • Dr. $doctor' : ''}',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                  if (tests.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: tests
                            .take(3)
                            .map((t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(t,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primary)),
                                ))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
            _PriorityBadge(priority: priority),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    switch (priority) {
      case 'stat':
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFDC2626);
        break;
      case 'urgent':
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        break;
      default:
        bgColor = const Color(0xFFE0F2FE);
        textColor = const Color(0xFF0284C7);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: textColor),
      ),
    );
  }
}
