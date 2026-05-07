import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

// ---------------------------------------------------------------------------
// Data provider – fetches doctor-relevant dashboard data in parallel
// ---------------------------------------------------------------------------

final _doctorDashboardProvider =
    FutureProvider.autoDispose<_DoctorDashboardData>((ref) async {
  final dio = ApiClient.instance;
  final today = DateTime.now().toIso8601String().split('T')[0];

  final results = await Future.wait<dynamic>([
    // 0 – today's appointments
    dio
        .get('/appointments/', queryParameters: {
          'appointment_date': today,
          'page_size': 100,
        })
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
    // 1 – consultations
    dio
        .get('/consultations/', queryParameters: {'page_size': 100})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
    // 2 – prescriptions
    dio
        .get('/prescriptions/', queryParameters: {'page_size': 100})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
    // 3 – patients
    dio
        .get('/patients/', queryParameters: {'page_size': 1})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'count': 0}),
    // 4 – lab orders pending
    dio
        .get('/lab/orders/',
            queryParameters: {'status': 'pending', 'page_size': 100})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
  ]);

  return _DoctorDashboardData(
    appointments: results[0] as Map<String, dynamic>,
    consultations: results[1] as Map<String, dynamic>,
    prescriptions: results[2] as Map<String, dynamic>,
    patients: results[3] as Map<String, dynamic>,
    labOrders: results[4] as Map<String, dynamic>,
  );
});

class _DoctorDashboardData {
  final Map<String, dynamic> appointments;
  final Map<String, dynamic> consultations;
  final Map<String, dynamic> prescriptions;
  final Map<String, dynamic> patients;
  final Map<String, dynamic> labOrders;

  _DoctorDashboardData({
    required this.appointments,
    required this.consultations,
    required this.prescriptions,
    required this.patients,
    required this.labOrders,
  });
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class DoctorDashboardScreen extends ConsumerWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final dashAsync = ref.watch(_doctorDashboardProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          _DashboardBanner(
            title:
                'Dr. ${user?.firstName ?? ''} ${user?.lastName ?? ''}',
            subtitle: user?.tenantName != null
                ? '${user!.tenantName} — today\'s overview'
                : 'Independent Practice — today\'s overview',
            initials:
                '${(user?.firstName ?? 'D')[0]}${(user?.lastName ?? '')[0]}',
            onRefresh: () => ref.invalidate(_doctorDashboardProvider),
          ),
          const SizedBox(height: 24),

          dashAsync.when(
            loading: () => const Center(child: LoadingWidget()),
            error: (e, _) => _buildFallbackDashboard(context),
            data: (data) => _buildLiveDashboard(context, data),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // FALLBACK (no data)
  // =========================================================================
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
                      icon: Icons.calendar_today_outlined,
                      title: "Today's Appointments",
                      value: '--',
                      color: AppColors.primary)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.medical_services_outlined,
                      title: 'Consultations',
                      value: '--',
                      color: AppColors.success)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.medication_outlined,
                      title: 'Prescriptions',
                      value: '--',
                      color: AppColors.secondary)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.science_outlined,
                      title: 'Pending Labs',
                      value: '--',
                      color: AppColors.warning)),
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

  // =========================================================================
  // LIVE DASHBOARD
  // =========================================================================
  Widget _buildLiveDashboard(
      BuildContext context, _DoctorDashboardData data) {
    final apptList =
        data.appointments['results'] as List<dynamic>? ?? [];
    final apptCount = data.appointments['count'] ?? 0;
    final consultCount = data.consultations['count'] ?? 0;
    final consultList =
        data.consultations['results'] as List<dynamic>? ?? [];
    final rxCount = data.prescriptions['count'] ?? 0;
    final rxList = data.prescriptions['results'] as List<dynamic>? ?? [];
    final patientCount = data.patients['count'] ?? 0;
    final labPending = data.labOrders['count'] ?? 0;
    final labList = data.labOrders['results'] as List<dynamic>? ?? [];

    // Appointment status counts
    final confirmedAppts =
        apptList.where((a) => a['status'] == 'confirmed').length;
    final inProgressAppts =
        apptList.where((a) => a['status'] == 'in_progress').length;
    final completedAppts =
        apptList.where((a) => a['status'] == 'completed').length;
    final scheduledAppts =
        apptList.where((a) => a['status'] == 'scheduled').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Row 1: Primary KPIs ──
        _SectionHeader("Today's Overview"),
        LayoutBuilder(builder: (ctx, c) {
          final cross = c.maxWidth > 900
              ? 5
              : c.maxWidth > 600
                  ? 3
                  : 2;
          final w = (c.maxWidth - (cross - 1) * 12) / cross;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.calendar_today,
                      title: 'Appointments',
                      value: '$apptCount',
                      color: AppColors.primary)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.medical_services,
                      title: 'Consultations',
                      value: '$consultCount',
                      color: AppColors.success)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.medication,
                      title: 'Prescriptions',
                      value: '$rxCount',
                      color: const Color(0xFF8B5CF6))),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.people,
                      title: 'Patients',
                      value: '$patientCount',
                      color: AppColors.secondary)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.science,
                      title: 'Pending Labs',
                      value: '$labPending',
                      color: AppColors.warning)),
            ],
          );
        }),
        const SizedBox(height: 24),

        // ── Quick Actions ──
        _SectionHeader('Quick Actions'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickAction(
                icon: Icons.event_available_outlined,
                label: 'New Appointment',
                color: AppColors.primary,
                onTap: () => context.push('/appointments/new')),
            _QuickAction(
                icon: Icons.medical_services_outlined,
                label: 'New Consultation',
                color: AppColors.success,
                onTap: () => context.push('/consultations/new')),
            _QuickAction(
                icon: Icons.people_outline,
                label: 'Patients',
                color: AppColors.secondary,
                onTap: () => context.push('/patients')),
            _QuickAction(
                icon: Icons.science_outlined,
                label: 'Lab Orders',
                color: AppColors.warning,
                onTap: () => context.push('/lab-orders')),
            _QuickAction(
                icon: Icons.medication_outlined,
                label: 'Prescriptions',
                color: const Color(0xFF8B5CF6),
                onTap: () => context.push('/prescriptions')),
            _QuickAction(
                icon: Icons.account_circle_outlined,
                label: 'My Profile',
                color: AppColors.secondary,
                onTap: () => context.push('/doctor-profile')),
          ],
        ),
        const SizedBox(height: 24),

        // ── Row 2: Appointments + Status Breakdown ──
        LayoutBuilder(builder: (ctx, c) {
          if (c.maxWidth > 1000) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    flex: 2,
                    child: _buildRecentAppointments(context, apptList)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildAppointmentStatusCard(context,
                        scheduled: scheduledAppts,
                        confirmed: confirmedAppts,
                        inProgress: inProgressAppts,
                        completed: completedAppts,
                        total: apptCount is int ? apptCount : 0)),
              ],
            );
          }
          return Column(
            children: [
              _buildRecentAppointments(context, apptList),
              const SizedBox(height: 16),
              _buildAppointmentStatusCard(context,
                  scheduled: scheduledAppts,
                  confirmed: confirmedAppts,
                  inProgress: inProgressAppts,
                  completed: completedAppts,
                  total: apptCount is int ? apptCount : 0),
            ],
          );
        }),
        const SizedBox(height: 24),

        // ── Row 3: Consultations + Prescriptions + Lab Orders ──
        LayoutBuilder(builder: (ctx, c) {
          if (c.maxWidth > 1000) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _buildRecentConsultations(context, consultList)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildRecentPrescriptions(context, rxList)),
                const SizedBox(width: 16),
                Expanded(child: _buildPendingLabOrders(context, labList)),
              ],
            );
          }
          if (c.maxWidth > 600) {
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child:
                            _buildRecentConsultations(context, consultList)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildRecentPrescriptions(context, rxList)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildPendingLabOrders(context, labList),
              ],
            );
          }
          return Column(
            children: [
              _buildRecentConsultations(context, consultList),
              const SizedBox(height: 16),
              _buildRecentPrescriptions(context, rxList),
              const SizedBox(height: 16),
              _buildPendingLabOrders(context, labList),
            ],
          );
        }),
      ],
    );
  }

  // =========================================================================
  // SECTION BUILDERS
  // =========================================================================

  Widget _buildRecentAppointments(
      BuildContext context, List<dynamic> appointments) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Today\'s Appointments',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/appointments'),
                child: const Text('View All', style: TextStyle(fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 12),
            if (appointments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('No appointments today',
                        style: TextStyle(color: AppColors.textSecondary))),
              ),
            ...appointments.take(5).map((appt) {
              final patientName =
                  appt['patient_name'] ?? appt['patient']?.toString() ?? '?';
              final time = appt['appointment_time'] ?? '';
              final status = appt['status'] ?? 'scheduled';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        (patientName is String && patientName.isNotEmpty)
                            ? patientName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$patientName',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          if (time.isNotEmpty)
                            Text(time,
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11)),
                        ],
                      ),
                    ),
                    _statusBadge(status),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentStatusCard(BuildContext context,
      {required int scheduled,
      required int confirmed,
      required int inProgress,
      required int completed,
      required int total}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.pie_chart_outline,
                  size: 18, color: AppColors.secondary),
              const SizedBox(width: 8),
              const Text('Status Breakdown',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ]),
            const SizedBox(height: 16),
            _statusRow('Scheduled', scheduled, AppColors.textSecondary, total),
            const SizedBox(height: 8),
            _statusRow('Confirmed', confirmed, AppColors.primary, total),
            const SizedBox(height: 8),
            _statusRow('In Progress', inProgress, AppColors.warning, total),
            const SizedBox(height: 8),
            _statusRow('Completed', completed, AppColors.success, total),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, int count, Color color, int total) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text('$count',
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentConsultations(
      BuildContext context, List<dynamic> consultations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.medical_services,
                  size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              const Text('Recent Consultations',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/consultations'),
                child: const Text('View All', style: TextStyle(fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 12),
            if (consultations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('No consultations yet',
                        style: TextStyle(color: AppColors.textSecondary))),
              ),
            ...consultations.take(5).map((c) {
              final patientName =
                  c['patient_name'] ?? c['patient']?.toString() ?? '?';
              final status = c['status'] ?? '';
              final date = c['created_at'] ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          AppColors.success.withValues(alpha: 0.1),
                      child: Text(
                        (patientName is String && patientName.isNotEmpty)
                            ? patientName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$patientName',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          if (date.isNotEmpty)
                            Text(date.toString().split('T')[0],
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11)),
                        ],
                      ),
                    ),
                    if (status.isNotEmpty) _statusBadge(status),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPrescriptions(
      BuildContext context, List<dynamic> prescriptions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.medication,
                  size: 18, color: const Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              const Text('Recent Prescriptions',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/prescriptions'),
                child: const Text('View All', style: TextStyle(fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 12),
            if (prescriptions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('No prescriptions yet',
                        style: TextStyle(color: AppColors.textSecondary))),
              ),
            ...prescriptions.take(5).map((rx) {
              final patientName =
                  rx['patient_name'] ?? rx['patient']?.toString() ?? '?';
              final status = rx['status'] ?? '';
              final date = rx['created_at'] ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      child: Text(
                        (patientName is String && patientName.isNotEmpty)
                            ? patientName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$patientName',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          if (date.isNotEmpty)
                            Text(date.toString().split('T')[0],
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11)),
                        ],
                      ),
                    ),
                    if (status.isNotEmpty) _statusBadge(status),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingLabOrders(
      BuildContext context, List<dynamic> labOrders) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.science, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              const Text('Pending Lab Orders',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/lab-orders'),
                child: const Text('View All', style: TextStyle(fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 12),
            if (labOrders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('No pending lab orders',
                        style: TextStyle(color: AppColors.textSecondary))),
              ),
            ...labOrders.take(5).map((lab) {
              final patientName =
                  lab['patient_name'] ?? lab['patient']?.toString() ?? '?';
              final testName = lab['test_name'] ?? lab['test']?.toString() ?? '';
              final status = lab['status'] ?? 'pending';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          AppColors.warning.withValues(alpha: 0.1),
                      child: Text(
                        (patientName is String && patientName.isNotEmpty)
                            ? patientName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$patientName',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          if (testName.isNotEmpty)
                            Text('$testName',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11)),
                        ],
                      ),
                    ),
                    _statusBadge(status),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
      case 'active':
      case 'completed':
      case 'paid':
      case 'dispensed':
        return AppColors.success;
      case 'in_progress':
      case 'processing':
      case 'sample_collected':
        return AppColors.warning;
      case 'cancelled':
      case 'overdue':
        return AppColors.error;
      case 'sent':
      case 'sent_to_exchange':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }
}

// ===========================================================================
// Dashboard Helpers
// ===========================================================================

class _DashboardBanner extends StatelessWidget {
  const _DashboardBanner({
    required this.title,
    required this.subtitle,
    required this.initials,
    required this.onRefresh,
  });

  final String title;
  final String subtitle;
  final String initials;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();
    final dateStr =
        '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month]} ${now.year}';
    final safeInitials = initials.isNotEmpty
        ? initials.substring(0, initials.length.clamp(0, 2)).toUpperCase()
        : '?';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.5, 1.0],
          colors: [Color(0xFF064E3B), Color(0xFF0F766E), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.18),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Center(
              child: Text(
                safeInitials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.today_rounded,
                        color: Color(0xFF5EEAD4), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: Color(0xFF5EEAD4),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Refresh',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF6366F1)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: -0.2),
          ),
        ],
      ),
    );
  }
}

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
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        splashColor: Colors.white24,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
