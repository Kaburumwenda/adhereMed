import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../widgets/common.dart';
import 'providers.dart';

class HomecarePatientDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const HomecarePatientDetailScreen({super.key, required this.id});

  @override
  ConsumerState<HomecarePatientDetailScreen> createState() => _HomecarePatientDetailScreenState();
}

class _HomecarePatientDetailScreenState extends ConsumerState<HomecarePatientDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patient = ref.watch(homecarePatientDetailProvider(widget.id));
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: patient.when(
        loading: () => const LoadingShimmer(lines: 8),
        error: (e, _) => ErrorRetry(
          message: 'Failed to load patient details',
          onRetry: () => ref.invalidate(homecarePatientDetailProvider(widget.id)),
        ),
        data: (data) => _buildContent(context, data, cs, isDark),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data, ColorScheme cs, bool isDark) {
    final user = data['user'] as Map<String, dynamic>? ?? {};
    final name = _patientName(user);
    final initials = _initials(name);
    final mrn = data['medical_record_number'] ?? '';
    final riskLevel = data['risk_level'] ?? 'low';
    final isActive = data['is_active'] ?? true;
    final diagnosis = data['primary_diagnosis'] ?? '';
    final allergies = data['allergies'] ?? '';
    final medicalHistory = data['medical_history'] ?? '';
    final address = data['address'] ?? '';
    final dob = data['date_of_birth'];
    final gender = data['gender'] ?? '';
    final phone = user['phone'] ?? '';
    final email = user['email'] ?? '';
    final age = data['age'] as num?;
    final emergencyContacts = (data['emergency_contacts'] as List?) ?? [];
    final String caregiverName;
    if (data['assigned_caregiver_name'] != null) {
      caregiverName = data['assigned_caregiver_name'];
    } else if (data['assigned_caregiver'] is Map) {
      caregiverName = (data['assigned_caregiver']['user']?['full_name'] ?? '') as String;
    } else {
      caregiverName = '';
    }
    final additionalCaregivers = data['additional_caregivers_detail'] as List? ?? [];
    final adherenceRate = data['adherence_rate'] as num?;

    final Color riskColor;
    switch (riskLevel) {
      case 'critical':
        riskColor = Colors.red;
      case 'high':
        riskColor = Colors.orange;
      case 'medium':
        riskColor = Colors.amber.shade700;
      default:
        riskColor = Colors.green;
    }

    return NestedScrollView(
      headerSliverBuilder: (_, __) => [
        // ── Hero AppBar ──
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
              onPressed: () {/* TODO: edit */},
            ),
            if (phone.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.phone_rounded, color: Colors.white),
                onPressed: () {/* TODO: call */},
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)]
                      : [const Color(0xFF0D9488), const Color(0xFF0EA5E9)],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name row
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: riskColor.withValues(alpha: 0.3),
                            child: Text(
                              initials,
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: mrn));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('MRN copied'), duration: Duration(seconds: 1)),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.18),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.tag_rounded, size: 12, color: Colors.white.withValues(alpha: 0.8)),
                                            const SizedBox(width: 4),
                                            Text(mrn, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: riskColor.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: riskColor.withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        riskLevel.toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: (isActive ? Colors.green : Colors.grey).withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isActive ? 'Active' : 'Closed',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Diagnosis & demographics
                      if (diagnosis.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.medical_information_rounded, size: 13, color: Colors.white.withValues(alpha: 0.7)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(diagnosis, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (gender.isNotEmpty) ...[
                            Icon(Icons.person_rounded, size: 13, color: Colors.white.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text(gender, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                            const SizedBox(width: 12),
                          ],
                          if (dob != null) ...[
                            Icon(Icons.cake_rounded, size: 13, color: Colors.white.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text('$dob${age != null ? ' · $age yrs' : ''}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                          ],
                        ],
                      ),
                      // ── Metric strip ──
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _HeroMetric(label: 'Adherence', value: adherenceRate != null ? '${adherenceRate.toInt()}%' : '—', icon: Icons.show_chart_rounded),
                          const SizedBox(width: 10),
                          _HeroMetric(label: 'Care team', value: '${(additionalCaregivers.length + (caregiverName.isNotEmpty ? 1 : 0))}', icon: Icons.groups_rounded),
                          const SizedBox(width: 10),
                          _HeroMetric(label: 'Contacts', value: '${emergencyContacts.length}', icon: Icons.contact_phone_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // ── Tab bar ──
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(
            TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurfaceVariant,
              indicatorColor: cs.primary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Care Team'),
                Tab(text: 'Medications'),
                Tab(text: 'Notes'),
                Tab(text: 'Insurance'),
              ],
            ),
            cs,
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          // ═══ Overview Tab ═══
          _OverviewTab(
            data: data,
            phone: phone,
            email: email,
            address: address,
            dob: dob,
            gender: gender,
            age: age,
            diagnosis: diagnosis,
            allergies: allergies,
            medicalHistory: medicalHistory,
            emergencyContacts: emergencyContacts,
            cs: cs,
          ),
          // ═══ Care Team Tab ═══
          _CareTeamTab(
            caregiverName: caregiverName,
            additionalCaregivers: additionalCaregivers,
            data: data,
            cs: cs,
          ),
          // ═══ Medications Tab ═══
          _MedicationsTab(patientId: widget.id, cs: cs),
          // ═══ Notes Tab ═══
          _NotesTab(cs: cs),
          // ═══ Insurance Tab ═══
          _InsuranceTab(cs: cs),
        ],
      ),
    );
  }

  String _patientName(Map<String, dynamic> user) {
    final full = (user['full_name'] ?? '').toString().trim();
    if (full.isNotEmpty) return full;
    final first = (user['first_name'] ?? '').toString();
    final last = (user['last_name'] ?? '').toString();
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) return combined;
    return user['email']?.toString() ?? 'Patient';
  }

  String _initials(String name) {
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'P';
  }
}

// ═══════════════════════════════════════════════════════════
// Hero Metric widget
// ═══════════════════════════════════════════════════════════
class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _HeroMetric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.8)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Tab bar delegate for pinned tab bar
// ═══════════════════════════════════════════════════════════
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final ColorScheme cs;
  _TabBarDelegate(this.tabBar, this.cs);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════
// Overview Tab
// ═══════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> data;
  final String phone, email, address, diagnosis, allergies, medicalHistory, gender;
  final dynamic dob;
  final num? age;
  final List emergencyContacts;
  final ColorScheme cs;

  const _OverviewTab({
    required this.data,
    required this.phone,
    required this.email,
    required this.address,
    required this.dob,
    required this.gender,
    required this.age,
    required this.diagnosis,
    required this.allergies,
    required this.medicalHistory,
    required this.emergencyContacts,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Contact info card
        _SectionCard(
          title: 'Contact Information',
          icon: Icons.person_rounded,
          color: const Color(0xFF0D9488),
          children: [
            if (phone.isNotEmpty) _DetailRow(icon: Icons.phone_rounded, label: 'Phone', value: phone),
            if (email.isNotEmpty) _DetailRow(icon: Icons.email_rounded, label: 'Email', value: email),
            if (address.isNotEmpty) _DetailRow(icon: Icons.location_on_rounded, label: 'Address', value: address),
            if (dob != null) _DetailRow(icon: Icons.cake_rounded, label: 'Date of Birth', value: '$dob${age != null ? ' ($age yrs)' : ''}'),
            if (gender.isNotEmpty) _DetailRow(icon: Icons.wc_rounded, label: 'Gender', value: gender),
          ],
        ).animate().fadeIn(duration: 250.ms),

        const SizedBox(height: 12),

        // Clinical info card
        _SectionCard(
          title: 'Clinical Information',
          icon: Icons.medical_information_rounded,
          color: const Color(0xFF0EA5E9),
          children: [
            if (diagnosis.isNotEmpty) _DetailRow(icon: Icons.healing_rounded, label: 'Primary Diagnosis', value: diagnosis),
            if (allergies.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 15, color: Colors.red.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: allergies.split(',').map((a) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_rounded, size: 11, color: Colors.red.shade400),
                              const SizedBox(width: 4),
                              Text(a.trim(), style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ).animate().fadeIn(delay: 100.ms, duration: 250.ms),

        if (medicalHistory.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Medical History',
            icon: Icons.history_rounded,
            color: const Color(0xFF6366F1),
            children: [
              Text(medicalHistory, style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.5)),
            ],
          ).animate().fadeIn(delay: 150.ms, duration: 250.ms),
        ],

        if (emergencyContacts.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Emergency Contacts',
            icon: Icons.emergency_rounded,
            color: const Color(0xFFEF4444),
            children: emergencyContacts.map((c) => _EmergencyContactRow(contact: c, cs: cs)).toList(),
          ).animate().fadeIn(delay: 200.ms, duration: 250.ms),
        ],

        const SizedBox(height: 80),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Care Team Tab
// ═══════════════════════════════════════════════════════════
class _CareTeamTab extends StatelessWidget {
  final String caregiverName;
  final List additionalCaregivers;
  final Map<String, dynamic> data;
  final ColorScheme cs;

  const _CareTeamTab({required this.caregiverName, required this.additionalCaregivers, required this.data, required this.cs});

  @override
  Widget build(BuildContext context) {
    final hasTeam = caregiverName.isNotEmpty || additionalCaregivers.isNotEmpty;

    if (!hasTeam) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_rounded, size: 64, color: cs.outlineVariant),
            const SizedBox(height: 12),
            Text('No caregivers assigned', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Assign a primary caregiver to begin care coordination.', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (caregiverName.isNotEmpty)
          _CaregiverCard(
            name: caregiverName,
            role: 'Primary Caregiver',
            isPrimary: true,
            caregiver: data['assigned_caregiver'] is Map ? data['assigned_caregiver'] : null,
            cs: cs,
          ).animate().fadeIn(duration: 250.ms),
        ...additionalCaregivers.map((c) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: _CaregiverCard(
            name: c['full_name'] ?? c['user']?['full_name'] ?? 'Caregiver',
            role: 'Additional Caregiver',
            isPrimary: false,
            caregiver: c,
            cs: cs,
          ),
        )),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _CaregiverCard extends StatelessWidget {
  final String name;
  final String role;
  final bool isPrimary;
  final dynamic caregiver;
  final ColorScheme cs;

  const _CaregiverCard({required this.name, required this.role, required this.isPrimary, this.caregiver, required this.cs});

  @override
  Widget build(BuildContext context) {
    final color = isPrimary ? const Color(0xFF0D9488) : Colors.purple;
    final email = caregiver?['user']?['email'] ?? caregiver?['email'] ?? '';
    final phone = caregiver?['user']?['phone'] ?? caregiver?['phone'] ?? '';
    final category = caregiver?['category'] ?? '';
    final specialties = caregiver?['specialties'] as List? ?? [];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(isPrimary ? Icons.star_rounded : Icons.person_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(isPrimary ? 'Primary' : 'Support', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (category.isNotEmpty)
                    _SmallInfoRow(icon: Icons.badge_rounded, text: category.toString().toUpperCase(), color: cs.onSurfaceVariant),
                  if (email.isNotEmpty)
                    _SmallInfoRow(icon: Icons.email_rounded, text: email, color: cs.onSurfaceVariant),
                  if (phone.isNotEmpty)
                    _SmallInfoRow(icon: Icons.phone_rounded, text: phone, color: cs.onSurfaceVariant),
                  if (specialties.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: specialties.map((s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                          child: Text(s.toString(), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                        )).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Medications Tab
// ═══════════════════════════════════════════════════════════
class _MedicationsTab extends ConsumerWidget {
  final int patientId;
  final ColorScheme cs;

  const _MedicationsTab({required this.patientId, required this.cs});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meds = ref.watch(homecareMedSchedulesProvider(patientId));

    return meds.when(
      loading: () => const LoadingShimmer(),
      error: (e, _) => ErrorRetry(
        message: 'Failed to load medications',
        onRetry: () => ref.invalidate(homecareMedSchedulesProvider(patientId)),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.medication_rounded, size: 64, color: cs.outlineVariant),
                const SizedBox(height: 12),
                Text('No medication schedules', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Active medications will appear here once scheduled.', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final m = list[i] as Map<String, dynamic>;
            final medName = m['medication_name'] ?? 'Medication';
            final dose = m['dose'] ?? '';
            final route = m['route'] ?? '';
            final frequency = m['frequency'] ?? '';
            final times = (m['times_of_day'] as List?) ?? [];
            final isActiveMed = m['is_active'] ?? true;
            final startDate = m['start_date'] ?? '';
            final endDate = m['end_date'];
            final instructions = m['instructions'] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.indigo.withValues(alpha: 0.1),
                          child: const Icon(Icons.medication_rounded, color: Colors.indigo, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(medName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              if (dose.isNotEmpty)
                                Text(dose, style: TextStyle(fontSize: 12, color: Colors.indigo.shade400, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isActiveMed ? Colors.green : Colors.grey).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isActiveMed ? 'Active' : 'Inactive',
                            style: TextStyle(fontSize: 10, color: isActiveMed ? Colors.green : Colors.grey, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (route.isNotEmpty)
                      _SmallInfoRow(icon: Icons.vaccines_rounded, text: 'Route: $route', color: cs.onSurfaceVariant),
                    if (frequency.isNotEmpty)
                      _SmallInfoRow(icon: Icons.repeat_rounded, text: 'Frequency: $frequency', color: cs.onSurfaceVariant),
                    if (startDate.isNotEmpty)
                      _SmallInfoRow(icon: Icons.calendar_today_rounded, text: 'Start: $startDate${endDate != null ? ' — End: $endDate' : ''}', color: cs.onSurfaceVariant),
                    if (times.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: times.map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.indigo.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule_rounded, size: 12, color: Colors.indigo.shade400),
                                const SizedBox(width: 4),
                                Text(t.toString(), style: TextStyle(fontSize: 11, color: Colors.indigo.shade600, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )).toList(),
                        ),
                      ),
                    if (instructions.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(instructions, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
            ).animate(delay: Duration(milliseconds: 50 * i)).fadeIn(duration: 250.ms);
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Notes Tab (placeholder)
// ═══════════════════════════════════════════════════════════
class _NotesTab extends StatelessWidget {
  final ColorScheme cs;
  const _NotesTab({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.note_alt_rounded, size: 64, color: cs.outlineVariant),
          const SizedBox(height: 12),
          Text('Care Notes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Clinical notes and observations will appear here.', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Insurance Tab (placeholder)
// ═══════════════════════════════════════════════════════════
class _InsuranceTab extends StatelessWidget {
  final ColorScheme cs;
  const _InsuranceTab({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, size: 64, color: cs.outlineVariant),
          const SizedBox(height: 12),
          Text('Insurance Policies', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Insurance policies and claims will appear here.', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Shared widgets
// ═══════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.icon, required this.color, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _SmallInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _SmallInfoRow({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _EmergencyContactRow extends StatelessWidget {
  final dynamic contact;
  final ColorScheme cs;
  const _EmergencyContactRow({required this.contact, required this.cs});

  @override
  Widget build(BuildContext context) {
    final name = contact['name'] ?? '';
    final phone = contact['phone'] ?? '';
    final relationship = contact['relationship'] ?? '';
    final isPrimary = contact['is_primary'] == true;
    final email = contact['email'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.red.withValues(alpha: 0.1),
            child: const Icon(Icons.contact_phone_rounded, size: 16, color: Colors.red),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    if (isPrimary) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text('Primary', style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                if (relationship.isNotEmpty)
                  Text(relationship, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (phone.isNotEmpty) ...[
                      Icon(Icons.phone_rounded, size: 11, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text(phone, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                    if (email.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.email_rounded, size: 11, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Expanded(child: Text(email, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
