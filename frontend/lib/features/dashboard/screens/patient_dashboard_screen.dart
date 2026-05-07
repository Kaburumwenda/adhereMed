import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

// ---------------------------------------------------------------------------
// Data provider – fetches patient-relevant dashboard data in parallel
// ---------------------------------------------------------------------------

final _patientDashboardProvider =
    FutureProvider.autoDispose<_PatientDashboardData>((ref) async {
  final dio = ApiClient.instance;

  final results = await Future.wait<dynamic>([
    // 0 – upcoming appointments
    dio
        .get('/appointments/', queryParameters: {'page_size': 10})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
    // 1 – prescription exchanges
    dio
        .get('/exchange/', queryParameters: {'page_size': 10})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
    // 2 – pharmacy orders
    dio
        .get('/exchange/orders/', queryParameters: {'page_size': 10})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
    // 3 – conversations
    dio
        .get('/messaging/conversations/')
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': [], 'count': 0}),
    // 4 – doctors
    dio
        .get('/doctors/', queryParameters: {'page_size': 12})
        .then((r) => r.data)
        .catchError((_) => <String, dynamic>{'results': []}),
  ]);

  return _PatientDashboardData(
    appointments: results[0] as Map<String, dynamic>,
    exchanges: results[1] as Map<String, dynamic>,
    orders: results[2] as Map<String, dynamic>,
    conversations: results[3],
    doctors: results[4] as Map<String, dynamic>,
  );
});

class _PatientDashboardData {
  final Map<String, dynamic> appointments;
  final Map<String, dynamic> exchanges;
  final Map<String, dynamic> orders;
  final dynamic conversations;
  final Map<String, dynamic> doctors;

  _PatientDashboardData({
    required this.appointments,
    required this.exchanges,
    required this.orders,
    required this.conversations,
    required this.doctors,
  });
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class PatientDashboardScreen extends ConsumerWidget {
  const PatientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final dashAsync = ref.watch(_patientDashboardProvider);

    final firstName = user?.firstName ?? 'Patient';
    final lastName = user?.lastName ?? '';
    final initials =
        '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
            .toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Banner ──
          _DashboardBanner(
            title: '$firstName $lastName'.trim(),
            subtitle: 'My Health Dashboard',
            initials: initials.isEmpty ? 'P' : initials,
            onRefresh: () => ref.invalidate(_patientDashboardProvider),
          ),
          const SizedBox(height: 24),

          dashAsync.when(
            loading: () => const Center(child: LoadingWidget()),
            error: (_, __) => _buildFallbackDashboard(context),
            data: (data) => _buildLiveDashboard(context, data),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // FALLBACK
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
                      title: 'Appointments',
                      value: '--',
                      color: AppColors.primary)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.receipt_outlined,
                      title: 'Prescriptions',
                      value: '--',
                      color: const Color(0xFF8B5CF6))),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.local_pharmacy_outlined,
                      title: 'Pharmacy Orders',
                      value: '--',
                      color: AppColors.success)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.chat_outlined,
                      title: 'Messages',
                      value: '--',
                      color: AppColors.secondary)),
            ],
          );
        }),
        const SizedBox(height: 24),
        _buildQuickActions(context),
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
      BuildContext context, _PatientDashboardData data) {
    final apptList =
        data.appointments['results'] as List<dynamic>? ?? [];
    final apptCount = data.appointments['count'] ?? apptList.length;

    final exchangeList =
        data.exchanges['results'] as List<dynamic>? ?? [];
    final exchangeCount = data.exchanges['count'] ?? exchangeList.length;

    final orderList =
        data.orders['results'] as List<dynamic>? ?? [];
    final orderCount = data.orders['count'] ?? orderList.length;

    final convRaw = data.conversations;
    final convList = convRaw is Map
        ? (convRaw['results'] as List<dynamic>? ?? [])
        : (convRaw is List ? convRaw : <dynamic>[]);
    final unreadCount = convList.fold<int>(
        0, (sum, c) => sum + ((c['unread_count'] as int?) ?? 0));

    final doctorList =
        data.doctors['results'] as List<dynamic>? ?? [];

    // Upcoming / active appointments
    final upcomingAppts = apptList
        .where((a) =>
            a['status'] == 'scheduled' || a['status'] == 'confirmed')
        .toList();

    // Active prescriptions in exchange (pending / quoted)
    final activeExchanges = exchangeList
        .where((e) =>
            e['status'] == 'pending' || e['status'] == 'quoted')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Stat cards ──
        _SectionHeader('Overview'),
        LayoutBuilder(builder: (ctx, c) {
          final cross = c.maxWidth > 900
              ? 4
              : c.maxWidth > 600
                  ? 2
                  : 1;
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
                      icon: Icons.receipt_long,
                      title: 'Prescriptions',
                      value: '$exchangeCount',
                      color: const Color(0xFF8B5CF6))),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.local_pharmacy,
                      title: 'Pharmacy Orders',
                      value: '$orderCount',
                      color: AppColors.success)),
              SizedBox(
                  width: w,
                  child: StatCard(
                      icon: Icons.chat,
                      title: 'Unread Messages',
                      value: '$unreadCount',
                      color: AppColors.secondary)),
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
                label: 'Book Appointment',
                color: AppColors.primary,
                onTap: () => context.push('/appointments/new')),
            _QuickAction(
                icon: Icons.receipt_outlined,
                label: 'My Prescriptions',
                color: const Color(0xFF8B5CF6),
                onTap: () => context.push('/my-prescriptions')),
            _QuickAction(
                icon: Icons.local_pharmacy_outlined,
                label: 'Browse Pharmacies',
                color: AppColors.success,
                onTap: () => context.push('/pharmacy-store')),
            _QuickAction(
                icon: Icons.chat_outlined,
                label: 'Message Doctor',
                color: AppColors.secondary,
                onTap: () => context.push('/messages')),
            _QuickAction(
                icon: Icons.search_outlined,
                label: 'Find Doctors',
                color: AppColors.warning,
                onTap: () => context.push('/doctors')),
          ],
        ),
        const SizedBox(height: 24),

        // ── Doctors ──
        if (doctorList.isNotEmpty) ...[
          _SectionHeader('Our Doctors'),
          _buildDoctorsSection(context, doctorList),
          const SizedBox(height: 24),
        ],

        // ── Upcoming Appointments + Active Exchanges ──
        LayoutBuilder(builder: (ctx, c) {
          if (c.maxWidth > 900) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    flex: 2,
                    child: _buildUpcomingAppointments(
                        context, upcomingAppts.isEmpty ? apptList : upcomingAppts)),
                const SizedBox(width: 16),
                Expanded(
                    child: _buildHealthSummaryCard(context,
                        apptList: apptList,
                        exchangeList: exchangeList,
                        orderList: orderList)),
              ],
            );
          }
          return Column(
            children: [
              _buildUpcomingAppointments(
                  context, upcomingAppts.isEmpty ? apptList : upcomingAppts),
              const SizedBox(height: 16),
              _buildHealthSummaryCard(context,
                  apptList: apptList,
                  exchangeList: exchangeList,
                  orderList: orderList),
            ],
          );
        }),
        const SizedBox(height: 24),

        // ── Prescription Exchanges + Orders + Conversations ──
        LayoutBuilder(builder: (ctx, c) {
          if (c.maxWidth > 900) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _buildPrescriptionExchanges(
                        context, activeExchanges.isEmpty ? exchangeList : activeExchanges)),
                const SizedBox(width: 16),
                Expanded(child: _buildPharmacyOrders(context, orderList)),
                const SizedBox(width: 16),
                Expanded(child: _buildConversations(context, convList)),
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
                        child: _buildPrescriptionExchanges(context,
                            activeExchanges.isEmpty ? exchangeList : activeExchanges)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildPharmacyOrders(context, orderList)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildConversations(context, convList),
              ],
            );
          }
          return Column(
            children: [
              _buildUpcomingAppointments(
                  context, upcomingAppts.isEmpty ? apptList : upcomingAppts,
                  alreadyBuilt: true),
              const SizedBox(height: 16),
              _buildPrescriptionExchanges(context,
                  activeExchanges.isEmpty ? exchangeList : activeExchanges),
              const SizedBox(height: 16),
              _buildPharmacyOrders(context, orderList),
              const SizedBox(height: 16),
              _buildConversations(context, convList),
            ],
          );
        }),
      ],
    );
  }

  // =========================================================================
  // SECTION BUILDERS
  // =========================================================================

  Widget _buildDoctorsSection(
      BuildContext context, List<dynamic> doctors) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: doctors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final doc = doctors[i] as Map<String, dynamic>;
          final name =
              '${doc['first_name'] ?? doc['user']?['first_name'] ?? ''} '
                      '${doc['last_name'] ?? doc['user']?['last_name'] ?? ''}'
                  .trim();
          final displayName = name.isNotEmpty ? name : 'Dr.';
          final photoUrl = doc['profile_picture_url'] as String?;
          final specialty = doc['specialization'] ??
              doc['specialization_name'] ??
              doc['specialty'] ??
              '';
          final docId = doc['id'];
          return _DoctorAvatarCard(
            name: displayName,
            specialty: specialty.toString(),
            photoUrl: photoUrl,
            onTap: docId != null
                ? () => context.push('/doctors/$docId')
                : null,
          );
        },
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('Quick Actions'),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickAction(
                icon: Icons.event_available_outlined,
                label: 'Book Appointment',
                color: AppColors.primary,
                onTap: () => context.push('/appointments/new')),
            _QuickAction(
                icon: Icons.receipt_outlined,
                label: 'My Prescriptions',
                color: const Color(0xFF8B5CF6),
                onTap: () => context.push('/my-prescriptions')),
            _QuickAction(
                icon: Icons.local_pharmacy_outlined,
                label: 'Browse Pharmacies',
                color: AppColors.success,
                onTap: () => context.push('/pharmacy-store')),
            _QuickAction(
                icon: Icons.chat_outlined,
                label: 'Message Doctor',
                color: AppColors.secondary,
                onTap: () => context.push('/messages')),
            _QuickAction(
                icon: Icons.search_outlined,
                label: 'Find Doctors',
                color: AppColors.warning,
                onTap: () => context.push('/doctors')),
          ],
        ),
      ],
    );
  }

  Widget _buildUpcomingAppointments(
      BuildContext context, List<dynamic> appointments,
      {bool alreadyBuilt = false}) {
    if (alreadyBuilt) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('Upcoming Appointments',
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
                  child: Column(
                    children: [
                      Icon(Icons.event_busy_outlined,
                          size: 36, color: AppColors.textSecondary),
                      const SizedBox(height: 8),
                      Text('No upcoming appointments',
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => context.push('/appointments/new'),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Book Now'),
                      ),
                    ],
                  ),
                ),
              ),
            ...appointments.take(5).map((appt) {
              final doctor =
                  appt['doctor_name'] ?? appt['doctor']?.toString() ?? 'Doctor';
              final dept = appt['department_name'] ?? '';
              final date = appt['date'] ?? '';
              final time = appt['start_time'] ?? appt['appointment_time'] ?? '';
              final status = appt['status'] ?? 'scheduled';
              final reason = appt['reason'] ?? appt['appointment_type'] ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.calendar_today,
                          size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doctor,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          if (dept.isNotEmpty)
                            Text(dept,
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11)),
                          if (date.isNotEmpty || time.isNotEmpty)
                            Text(
                              [date, time]
                                  .where((s) => s.isNotEmpty)
                                  .join(' • '),
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11),
                            ),
                          if (reason.isNotEmpty)
                            Text(reason,
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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

  Widget _buildHealthSummaryCard(
    BuildContext context, {
    required List<dynamic> apptList,
    required List<dynamic> exchangeList,
    required List<dynamic> orderList,
  }) {
    final scheduled =
        apptList.where((a) => a['status'] == 'scheduled').length;
    final confirmed =
        apptList.where((a) => a['status'] == 'confirmed').length;
    final completed =
        apptList.where((a) => a['status'] == 'completed').length;

    final pendingRx =
        exchangeList.where((e) => e['status'] == 'pending').length;
    final quotedRx =
        exchangeList.where((e) => e['status'] == 'quoted').length;
    final acceptedRx =
        exchangeList.where((e) => e['status'] == 'accepted').length;

    final pendingOrders =
        orderList.where((o) => o['status'] == 'pending').length;
    final processingOrders =
        orderList.where((o) => o['status'] == 'processing').length;
    final completedOrders =
        orderList.where((o) => o['status'] == 'completed').length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.health_and_safety_outlined,
                  size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              const Text('Health Summary',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ]),
            const SizedBox(height: 16),
            // Appointment breakdown
            _summarySection(
              'Appointments',
              [
                _SummaryStat('Scheduled', scheduled, AppColors.textSecondary),
                _SummaryStat('Confirmed', confirmed, AppColors.primary),
                _SummaryStat('Completed', completed, AppColors.success),
              ],
            ),
            const Divider(height: 20),
            // Prescription breakdown
            _summarySection(
              'Prescriptions',
              [
                _SummaryStat('Pending', pendingRx, AppColors.warning),
                _SummaryStat('Quoted', quotedRx, AppColors.primary),
                _SummaryStat('Accepted', acceptedRx, AppColors.success),
              ],
            ),
            const Divider(height: 20),
            // Order breakdown
            _summarySection(
              'Pharmacy Orders',
              [
                _SummaryStat('Pending', pendingOrders, AppColors.warning),
                _SummaryStat('Processing', processingOrders, AppColors.secondary),
                _SummaryStat('Completed', completedOrders, AppColors.success),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summarySection(String title, List<_SummaryStat> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Row(
          children: stats.map((s) {
            return Expanded(
              child: Column(
                children: [
                  Text('${s.count}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: s.color)),
                  const SizedBox(height: 2),
                  Text(s.label,
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary),
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPrescriptionExchanges(
      BuildContext context, List<dynamic> exchanges) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.receipt_long,
                  size: 18, color: const Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('My Prescriptions',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              TextButton(
                onPressed: () => context.push('/my-prescriptions'),
                child: const Text('View All', style: TextStyle(fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 12),
            if (exchanges.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_outlined,
                          size: 36, color: AppColors.textSecondary),
                      const SizedBox(height: 8),
                      Text('No active prescriptions',
                          style:
                              TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ...exchanges.take(5).map((ex) {
              final ref = ex['prescription_ref'] ??
                  ex['prescriptionRef'] ??
                  '#${ex['id']}';
              final status = ex['status'] ?? 'pending';
              final date = ex['created_at'] ?? '';
              final quotesCount = (ex['quotes'] as List?)?.length ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.receipt_long,
                          size: 18, color: Color(0xFF8B5CF6)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rx $ref',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          if (date.isNotEmpty)
                            Text(date.toString().split('T')[0],
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11)),
                          if (quotesCount > 0)
                            Text('$quotesCount quote${quotesCount > 1 ? 's' : ''} available',
                                style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => context.push('/exchange/${ex['id']}'),
                      child: _statusBadge(status),
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

  Widget _buildPharmacyOrders(
      BuildContext context, List<dynamic> orders) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.local_pharmacy, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Pharmacy Orders',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              TextButton(
                onPressed: () => context.push('/pharmacy-store/orders'),
                child: const Text('View All', style: TextStyle(fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 12),
            if (orders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          size: 36, color: AppColors.textSecondary),
                      const SizedBox(height: 8),
                      Text('No pharmacy orders yet',
                          style:
                              TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => context.push('/pharmacy-store'),
                        icon: const Icon(Icons.local_pharmacy_outlined,
                            size: 16),
                        label: const Text('Browse Pharmacies'),
                      ),
                    ],
                  ),
                ),
              ),
            ...orders.take(5).map((order) {
              final orderId = '#${order['id']}';
              final status = order['status'] ?? 'pending';
              final date = order['created_at'] ?? '';
              final pharmacyName =
                  order['pharmacy_name'] ?? order['pharmacy'] ?? '';
              final total = order['total_amount'] ??
                  order['total_cost'] ??
                  order['totalAmount'] ??
                  0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.shopping_bag_outlined,
                          size: 18, color: AppColors.success),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order $orderId',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                          if (pharmacyName.toString().isNotEmpty)
                            Text('$pharmacyName',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11),
                                overflow: TextOverflow.ellipsis),
                          if (date.isNotEmpty)
                            Text(date.toString().split('T')[0],
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11)),
                          if (total != 0)
                            Text('KES ${total.toStringAsFixed != null ? (total is num ? total.toStringAsFixed(2) : total) : total}',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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

  Widget _buildConversations(
      BuildContext context, List<dynamic> conversations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.chat, size: 18, color: AppColors.secondary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Messages',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
              TextButton(
                onPressed: () => context.push('/messages'),
                child: const Text('View All', style: TextStyle(fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 12),
            if (conversations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 36, color: AppColors.textSecondary),
                      const SizedBox(height: 8),
                      Text('No messages yet',
                          style:
                              TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => context.push('/doctors'),
                        icon: const Icon(Icons.search, size: 16),
                        label: const Text('Find a Doctor'),
                      ),
                    ],
                  ),
                ),
              ),
            ...conversations.take(5).map((conv) {
              final doctorName =
                  conv['doctor_name'] ?? conv['doctor']?.toString() ?? 'Doctor';
              final subject = conv['subject'] ?? '';
              final lastMsg = conv['last_message'];
              final lastContent = lastMsg is Map
                  ? (lastMsg['content'] ?? '')
                  : '';
              final unread = conv['unread_count'] ?? 0;
              final convId = conv['id'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => context.push('/messages/$convId'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              AppColors.secondary.withValues(alpha: 0.1),
                          child: Text(
                            doctorName.isNotEmpty
                                ? doctorName[0].toUpperCase()
                                : 'D',
                            style: TextStyle(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(doctorName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                  overflow: TextOverflow.ellipsis),
                              if (subject.isNotEmpty)
                                Text(subject,
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11),
                                    overflow: TextOverflow.ellipsis),
                              if (lastContent.isNotEmpty)
                                Text(lastContent,
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1),
                            ],
                          ),
                        ),
                        if (unread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unread',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                  ),
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
      case 'accepted':
      case 'delivered':
        return AppColors.success;
      case 'in_progress':
      case 'processing':
      case 'quoted':
      case 'ready':
        return AppColors.warning;
      case 'cancelled':
      case 'overdue':
      case 'expired':
        return AppColors.error;
      case 'sent':
      case 'sent_to_exchange':
      case 'scheduled':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }
}

// ===========================================================================
// Doctor Avatar Card
// ===========================================================================

class _DoctorAvatarCard extends StatelessWidget {
  final String name;
  final String specialty;
  final String? photoUrl;
  final VoidCallback? onTap;

  const _DoctorAvatarCard({
    required this.name,
    required this.specialty,
    this.photoUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Avatar ──────────────────────────────────────────────
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 1.5),
              ),
              child: ClipOval(
                child: photoUrl != null && photoUrl!.isNotEmpty
                    ? Image.network(
                        photoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            initials.isEmpty ? 'D' : initials,
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 18),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initials.isEmpty ? 'D' : initials,
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 18),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            // ── Name ─────────────────────────────────────────────────
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.3),
            ),
            if (specialty.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                specialty,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Summary stat helper
// ===========================================================================

class _SummaryStat {
  final String label;
  final int count;
  final Color color;
  const _SummaryStat(this.label, this.count, this.color);
}

// ===========================================================================
// Dashboard Helpers (local to this file)
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
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
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
                  'Welcome, $title',
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
                  Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
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
