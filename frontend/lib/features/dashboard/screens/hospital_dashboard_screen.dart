import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

// ---------------------------------------------------------------------------
// Data provider – fetches all dashboard data in parallel
// ---------------------------------------------------------------------------

final _hospitalDashboardProvider =
    FutureProvider.autoDispose<_HospitalDashboardData>((ref) async {
  final dio = ApiClient.instance;

  final results = await Future.wait<dynamic>([
    // 0 – appointments (today, all statuses)
    dio
        .get('/appointments/', queryParameters: {
          'appointment_date': DateTime.now().toIso8601String().split('T')[0],
          'page_size': 100,
        })
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
    // 1 – patients
    dio
        .get('/patients/', queryParameters: {'page_size': 1})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'count': 0}),
    // 2 – lab orders pending
    dio
        .get('/lab/orders/',
            queryParameters: {'status': 'pending', 'page_size': 100})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
    // 3 – invoices (unpaid)
    dio
        .get('/billing/invoices/',
            queryParameters: {'status': 'sent', 'page_size': 100})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
    // 4 – consultations today
    dio
        .get('/consultations/', queryParameters: {'page_size': 100})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
    // 5 – triage records
    dio
        .get('/triage/', queryParameters: {'page_size': 100})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
    // 6 – departments
    dio
        .get('/departments/', queryParameters: {'page_size': 100})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
    // 7 – prescriptions
    dio
        .get('/prescriptions/', queryParameters: {'page_size': 100})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
    // 8 – wards
    dio
        .get('/wards/wards/', queryParameters: {'page_size': 100})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
    // 9 – admissions (active)
    dio
        .get('/wards/admissions/',
            queryParameters: {'status': 'active', 'page_size': 100})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
    // 10 – beds
    dio
        .get('/wards/beds/', queryParameters: {'page_size': 200})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
  ]);

  return _HospitalDashboardData(
    appointments: results[0] as Map<String, dynamic>,
    patients: results[1] as Map<String, dynamic>,
    labOrders: results[2] as Map<String, dynamic>,
    invoices: results[3] as Map<String, dynamic>,
    consultations: results[4] as Map<String, dynamic>,
    triage: results[5] as Map<String, dynamic>,
    departments: results[6] as Map<String, dynamic>,
    prescriptions: results[7] as Map<String, dynamic>,
    wards: results[8] as Map<String, dynamic>,
    admissions: results[9] as Map<String, dynamic>,
    beds: results[10] as Map<String, dynamic>,
  );
});

class _HospitalDashboardData {
  final Map<String, dynamic> appointments;
  final Map<String, dynamic> patients;
  final Map<String, dynamic> labOrders;
  final Map<String, dynamic> invoices;
  final Map<String, dynamic> consultations;
  final Map<String, dynamic> triage;
  final Map<String, dynamic> departments;
  final Map<String, dynamic> prescriptions;
  final Map<String, dynamic> wards;
  final Map<String, dynamic> admissions;
  final Map<String, dynamic> beds;

  _HospitalDashboardData({
    required this.appointments,
    required this.patients,
    required this.labOrders,
    required this.invoices,
    required this.consultations,
    required this.triage,
    required this.departments,
    required this.prescriptions,
    required this.wards,
    required this.admissions,
    required this.beds,
  });
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class HospitalDashboardScreen extends ConsumerWidget {
  const HospitalDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final dashAsync = ref.watch(_hospitalDashboardProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          _DashboardBanner(
            title: user?.tenantName ?? 'Hospital Dashboard',
            subtitle:
                'Welcome back, ${user?.firstName ?? 'Admin'} — today\'s overview',
            initials:
                '${(user?.firstName ?? 'H')[0]}${(user?.lastName ?? '')[0]}',
            onRefresh: () => ref.invalidate(_hospitalDashboardProvider),
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
          final cross =
              c.maxWidth > 900 ? 4 : c.maxWidth > 600 ? 2 : 1;
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
                      icon: Icons.people_outline,
                      title: 'Total Patients',
                      value: '--',
                      color: AppColors.secondary)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.science_outlined,
                      title: 'Pending Lab Orders',
                      value: '--',
                      color: AppColors.warning)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.receipt_long_outlined,
                      title: 'Pending Invoices',
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

  // =========================================================================
  // LIVE DASHBOARD
  // =========================================================================
  Widget _buildLiveDashboard(
      BuildContext context, _HospitalDashboardData data) {
    final apptList =
        data.appointments['results'] as List<dynamic>? ?? [];
    final apptCount = data.appointments['count'] ?? 0;
    final patientCount = data.patients['count'] ?? 0;
    final labPending = data.labOrders['count'] ?? 0;
    final invoicePending = data.invoices['count'] ?? 0;
    final consultCount = data.consultations['count'] ?? 0;
    final triageCount = data.triage['count'] ?? 0;
    final deptCount = data.departments['count'] ?? 0;
    final rxCount = data.prescriptions['count'] ?? 0;
    final wardList = data.wards['results'] as List<dynamic>? ?? [];
    final admissionCount = data.admissions['count'] ?? 0;
    final bedList = data.beds['results'] as List<dynamic>? ?? [];
    final invoiceList =
        data.invoices['results'] as List<dynamic>? ?? [];
    final labList = data.labOrders['results'] as List<dynamic>? ?? [];
    final triageList = data.triage['results'] as List<dynamic>? ?? [];
    final rxList =
        data.prescriptions['results'] as List<dynamic>? ?? [];
    final consultList =
        data.consultations['results'] as List<dynamic>? ?? [];

    // Compute bed stats
    final totalBeds = bedList.length;
    final availableBeds = bedList
        .where((b) => (b['status'] ?? '') == 'available')
        .length;
    final occupiedBeds = bedList
        .where((b) => (b['status'] ?? '') == 'occupied')
        .length;

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
          final cross = c.maxWidth > 1100
              ? 6
              : c.maxWidth > 700
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
                      icon: Icons.people,
                      title: 'Total Patients',
                      value: '$patientCount',
                      color: AppColors.secondary)),
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
                      icon: Icons.science,
                      title: 'Pending Labs',
                      value: '$labPending',
                      color: AppColors.warning)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.receipt_long,
                      title: 'Pending Invoices',
                      value: '$invoicePending',
                      color: AppColors.error)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.medication,
                      title: 'Prescriptions',
                      value: '$rxCount',
                      color: const Color(0xFF8B5CF6))),
            ],
          );
        }),
        const SizedBox(height: 24),

        // ── Row 2: Capacity KPIs ──
        _SectionHeader('Hospital Capacity'),
        LayoutBuilder(builder: (ctx, c) {
          final cross = c.maxWidth > 1100
              ? 6
              : c.maxWidth > 700
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
                      icon: Icons.local_hospital,
                      title: 'Departments',
                      value: '$deptCount',
                      color: AppColors.primary)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.bed,
                      title: 'Total Beds',
                      value: '$totalBeds',
                      color: AppColors.secondary)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.check_circle_outline,
                      title: 'Available Beds',
                      value: '$availableBeds',
                      color: AppColors.success)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.hotel,
                      title: 'Occupied Beds',
                      value: '$occupiedBeds',
                      color: AppColors.warning)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.transfer_within_a_station,
                      title: 'Admissions',
                      value: '$admissionCount',
                      color: const Color(0xFFF97316))),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.emergency,
                      title: 'Triage Today',
                      value: '$triageCount',
                      color: AppColors.error)),
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
                icon: Icons.person_add_outlined,
                label: 'Register Patient',
                color: AppColors.secondary,
                onTap: () => context.push('/patients/new')),
            _QuickAction(
                icon: Icons.medical_services_outlined,
                label: 'New Consultation',
                color: AppColors.success,
                onTap: () => context.push('/consultations/new')),
            _QuickAction(
                icon: Icons.monitor_heart_outlined,
                label: 'Triage',
                color: AppColors.warning,
                onTap: () => context.push('/triage/new')),
            _QuickAction(
                icon: Icons.science_outlined,
                label: 'Lab Orders',
                color: const Color(0xFF8B5CF6),
                onTap: () => context.push('/lab-orders')),
            _QuickAction(
                icon: Icons.receipt_long_outlined,
                label: 'Invoices',
                color: const Color(0xFF06B6D4),
                onTap: () => context.push('/billing')),
            _QuickAction(
                icon: Icons.domain_outlined,
                label: 'Wards',
                color: const Color(0xFFF97316),
                onTap: () => context.push('/wards')),
            _QuickAction(
                icon: Icons.image_outlined,
                label: 'Radiology',
                color: const Color(0xFFEC4899),
                onTap: () => context.push('/radiology')),
          ],
        ),
        const SizedBox(height: 24),

        // ── Row 3: Appointments + Appointment Status Breakdown ──
        LayoutBuilder(builder: (ctx, c) {
          if (c.maxWidth > 1000) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildRecentAppointments(context, apptList)),
                const SizedBox(width: 16),
                Expanded(child: _buildAppointmentStatusCard(context,
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

        // ── Row 4: Lab Orders + Invoices + Prescriptions ──
        LayoutBuilder(builder: (ctx, c) {
          if (c.maxWidth > 1000) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildPendingLabOrders(context, labList)),
                const SizedBox(width: 16),
                Expanded(child: _buildPendingInvoices(context, invoiceList)),
                const SizedBox(width: 16),
                Expanded(child: _buildRecentPrescriptions(context, rxList)),
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
                        child: _buildPendingLabOrders(context, labList)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildPendingInvoices(context, invoiceList)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRecentPrescriptions(context, rxList),
              ],
            );
          }
          return Column(
            children: [
              _buildPendingLabOrders(context, labList),
              const SizedBox(height: 16),
              _buildPendingInvoices(context, invoiceList),
              const SizedBox(height: 16),
              _buildRecentPrescriptions(context, rxList),
            ],
          );
        }),
        const SizedBox(height: 24),

        // ── Row 5: Ward Overview + Triage + Recent Consultations ──
        LayoutBuilder(builder: (ctx, c) {
          if (c.maxWidth > 1000) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildWardOverview(context, wardList)),
                const SizedBox(width: 16),
                Expanded(child: _buildTriageRecords(context, triageList)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildRecentConsultations(context, consultList)),
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
                        child: _buildWardOverview(context, wardList)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildTriageRecords(context, triageList)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRecentConsultations(context, consultList),
              ],
            );
          }
          return Column(
            children: [
              _buildWardOverview(context, wardList),
              const SizedBox(height: 16),
              _buildTriageRecords(context, triageList),
              const SizedBox(height: 16),
              _buildRecentConsultations(context, consultList),
            ],
          );
        }),
      ],
    );
  }

  // =========================================================================
  // SECTION BUILDERS
  // =========================================================================

  // == Recent Appointments ==================================================
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
              const Text('Recent Appointments',
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
                    child: Text('No appointments found',
                        style: TextStyle(color: AppColors.textSecondary))),
              ),
            ...appointments.take(5).map((appt) {
              final patientName =
                  appt['patient_name'] ?? appt['patient']?.toString() ?? '?';
              final time = appt['appointment_time'] ?? '';
              final dept = appt['department_name'] ?? '';
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
                          Text('$dept${time.isNotEmpty ? ' • $time' : ''}',
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

  // == Appointment Status Breakdown =========================================
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
              const Text('Appointment Status',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ]),
            const SizedBox(height: 16),
            _statusRow('Scheduled', scheduled, AppColors.textSecondary,
                total),
            const SizedBox(height: 8),
            _statusRow('Confirmed', confirmed, AppColors.success, total),
            const SizedBox(height: 8),
            _statusRow('In Progress', inProgress, AppColors.warning, total),
            const SizedBox(height: 8),
            _statusRow('Completed', completed, AppColors.primary, total),
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
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // == Pending Lab Orders ===================================================
  Widget _buildPendingLabOrders(
      BuildContext context, List<dynamic> orders) {
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
            if (orders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('No pending lab orders',
                        style: TextStyle(color: AppColors.textSecondary))),
              ),
            ...orders.take(5).map((o) {
              final patient = o['patient_name'] ??
                  o['patient']?.toString() ??
                  'Unknown';
              final priority = o['priority'] ?? 'routine';
              final status = o['status'] ?? 'pending';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.biotech,
                          size: 16, color: AppColors.warning),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$patient',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          Text('Priority: $priority',
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

  // == Pending Invoices =====================================================
  Widget _buildPendingInvoices(
      BuildContext context, List<dynamic> invoices) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.receipt_long, size: 18, color: AppColors.error),
              const SizedBox(width: 8),
              const Text('Pending Invoices',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/billing'),
                child: const Text('View All', style: TextStyle(fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 12),
            if (invoices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('No pending invoices',
                        style: TextStyle(color: AppColors.textSecondary))),
              ),
            ...invoices.take(5).map((inv) {
              final invoiceNo =
                  inv['invoice_number'] ?? '#${inv['id'] ?? ''}';
              final patient = inv['patient_name'] ??
                  inv['patient']?.toString() ??
                  'Unknown';
              final total = inv['total'] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.description,
                          size: 16, color: AppColors.error),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$invoiceNo',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 13)),
                          Text('$patient',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11)),
                        ],
                      ),
                    ),
                    Text(_fmt(total),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // == Recent Prescriptions =================================================
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
                    child: Text('No prescriptions',
                        style: TextStyle(color: AppColors.textSecondary))),
              ),
            ...prescriptions.take(5).map((rx) {
              final patient = rx['patient_name'] ??
                  rx['patient']?.toString() ??
                  'Unknown';
              final status = rx['status'] ?? 'active';
              final doctor = rx['doctor_name'] ??
                  rx['doctor']?.toString() ??
                  '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.description_outlined,
                          size: 16, color: const Color(0xFF8B5CF6)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$patient',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          if (doctor.isNotEmpty)
                            Text('Dr. $doctor',
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

  // == Ward Overview ========================================================
  Widget _buildWardOverview(
      BuildContext context, List<dynamic> wards) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.domain, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Wards',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ]),
            const SizedBox(height: 12),
            if (wards.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('No wards configured',
                        style: TextStyle(color: AppColors.textSecondary))),
              ),
            ...wards.take(6).map((ward) {
              final name = ward['name'] ?? 'Ward';
              final type = ward['type'] ?? '';
              final beds = ward['total_beds'] ?? ward['beds']?.length ?? 0;
              final available = ward['available_beds'] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.bed,
                          size: 16, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$name',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          Text(type.toString().toUpperCase(),
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$available / $beds',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: available > 0
                                    ? AppColors.success
                                    : AppColors.error)),
                        Text('available',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // == Triage Records =======================================================
  Widget _buildTriageRecords(
      BuildContext context, List<dynamic> triageRecords) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.emergency, size: 18, color: AppColors.error),
              const SizedBox(width: 8),
              const Text('Recent Triage',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/triage'),
                child: const Text('View All', style: TextStyle(fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 12),
            if (triageRecords.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: Text('No triage records',
                        style: TextStyle(color: AppColors.textSecondary))),
              ),
            ...triageRecords.take(5).map((t) {
              final patient = t['patient_name'] ??
                  t['patient']?.toString() ??
                  'Unknown';
              final esi = t['esi_level'] ?? 5;
              final complaint = t['chief_complaint'] ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _esiColor(esi).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text('$esi',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: _esiColor(esi))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$patient',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          if (complaint.isNotEmpty)
                            Text('$complaint',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1),
                        ],
                      ),
                    ),
                    Text('ESI $esi',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                            color: _esiColor(esi))),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // == Recent Consultations =================================================
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
                    child: Text('No consultations',
                        style: TextStyle(color: AppColors.textSecondary))),
              ),
            ...consultations.take(5).map((c) {
              final patient = c['patient_name'] ??
                  c['patient']?.toString() ??
                  'Unknown';
              final complaint = c['chief_complaint'] ?? '';
              final diagnosis = c['diagnosis'];
              final diagText = diagnosis is List
                  ? (diagnosis.isNotEmpty
                      ? diagnosis.first.toString()
                      : '')
                  : diagnosis?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.healing,
                          size: 16, color: AppColors.success),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$patient',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          Text(complaint.isNotEmpty ? complaint : diagText,
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1),
                        ],
                      ),
                    ),
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
      case 'partially_paid':
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

  Color _esiColor(dynamic esi) {
    final level = esi is int ? esi : int.tryParse('$esi') ?? 5;
    switch (level) {
      case 1:
        return const Color(0xFFDC2626); // Red – resuscitation
      case 2:
        return const Color(0xFFF97316); // Orange – emergent
      case 3:
        return const Color(0xFFEAB308); // Yellow – urgent
      case 4:
        return const Color(0xFF22C55E); // Green – less urgent
      case 5:
        return const Color(0xFF3B82F6); // Blue – non-urgent
      default:
        return AppColors.textSecondary;
    }
  }

  String _fmt(dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
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
