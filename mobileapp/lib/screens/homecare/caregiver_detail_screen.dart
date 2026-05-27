import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../widgets/common.dart';
import 'providers.dart';

class HomecareCaregiverDetailScreen extends ConsumerStatefulWidget {
  const HomecareCaregiverDetailScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<HomecareCaregiverDetailScreen> createState() => _HomecareCaregiverDetailScreenState();
}

class _HomecareCaregiverDetailScreenState extends ConsumerState<HomecareCaregiverDetailScreen> {
  bool _updatingAvailability = false;

  Future<void> _refreshAll() async {
    ref.invalidate(homecareCaregiverOverviewProvider(widget.id));
    ref.invalidate(homecareCaregiversProvider);
    await ref.read(homecareCaregiverOverviewProvider(widget.id).future);
  }

  Future<void> _toggleAvailability(bool currentlyAvailable) async {
    if (_updatingAvailability) return;
    setState(() => _updatingAvailability = true);
    try {
      await ref.read(dioProvider).post('/homecare/caregivers/${widget.id}/toggle_availability/');
      await _refreshAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(currentlyAvailable ? 'Caregiver set off duty' : 'Caregiver marked available')),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      final message = data is Map && data['detail'] != null
          ? data['detail'].toString()
          : 'Failed to update caregiver availability.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _updatingAvailability = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(homecareCaregiverOverviewProvider(widget.id));

    return Scaffold(
      body: overviewAsync.when(
        loading: () => const LoadingShimmer(lines: 12),
        error: (error, _) => ErrorRetry(
          message: 'Failed to load caregiver details',
          onRetry: () => ref.invalidate(homecareCaregiverOverviewProvider(widget.id)),
        ),
        data: (payload) {
          final caregiver = Map<String, dynamic>.from(payload['caregiver'] as Map);
          final visits = (payload['visits'] as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList()
            ..sort((a, b) => (a['start_at'] ?? '').toString().compareTo((b['start_at'] ?? '').toString()));
          final patients = (payload['patients'] as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          final user = caregiver['user'] as Map<String, dynamic>? ?? const {};
          final name = _caregiverName(caregiver);
          final meta = _caregiverMeta(caregiver['category']?.toString());
          final employmentStatus = caregiver['employment_status']?.toString() ?? 'active';
          final isAvailable = caregiver['is_available'] == true;
          final rating = (caregiver['rating'] as num?)?.toDouble() ?? 0;
          final activePatients = (caregiver['active_patients_count'] as num?)?.toInt() ?? patients.length;
          final totalVisits = (caregiver['total_visits'] as num?)?.toInt() ?? visits.length;
          final certifications = ((caregiver['certifications'] as List?) ?? const [])
              .map((item) => item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{'name': item.toString()})
              .toList();
          final specialties = ((caregiver['specialties'] as List?) ?? const []).map((item) => item.toString()).where((item) => item.isNotEmpty).toList();

          return DefaultTabController(
            length: 3,
            child: RefreshIndicator(
              onRefresh: _refreshAll,
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      expandedHeight: 322,
                      pinned: true,
                      stretch: true,
                      backgroundColor: meta.gradient.first,
                      foregroundColor: Colors.white,
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      bottom: const TabBar(
                        tabs: [
                          Tab(text: 'Profile', icon: Icon(Icons.account_box_rounded)),
                          Tab(text: 'Visits', icon: Icon(Icons.calendar_month_rounded)),
                          Tab(text: 'Patients', icon: Icon(Icons.groups_rounded)),
                        ],
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        background: _CaregiverHeroHeader(
                          caregiver: caregiver,
                          name: name,
                          meta: meta,
                          activePatients: activePatients,
                          totalVisits: totalVisits,
                          rating: rating,
                          employmentStatus: employmentStatus,
                          isAvailable: isAvailable,
                          email: user['email']?.toString() ?? '',
                          licenseNumber: caregiver['license_number']?.toString() ?? '',
                          onToggleAvailability: () => _toggleAvailability(isAvailable),
                          updatingAvailability: _updatingAvailability,
                        ),
                      ),
                    ),
                  ];
                },
                body: TabBarView(
                  children: [
                    _ProfileTab(
                      caregiver: caregiver,
                      user: user,
                      specialties: specialties,
                      certifications: certifications,
                      meta: meta,
                    ),
                    _VisitsTab(visits: visits),
                    _PatientsTab(patients: patients),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CaregiverHeroHeader extends StatelessWidget {
  const _CaregiverHeroHeader({
    required this.caregiver,
    required this.name,
    required this.meta,
    required this.activePatients,
    required this.totalVisits,
    required this.rating,
    required this.employmentStatus,
    required this.isAvailable,
    required this.email,
    required this.licenseNumber,
    required this.onToggleAvailability,
    required this.updatingAvailability,
  });

  final Map<String, dynamic> caregiver;
  final String name;
  final _CaregiverMeta meta;
  final int activePatients;
  final int totalVisits;
  final double rating;
  final String employmentStatus;
  final bool isAvailable;
  final String email;
  final String licenseNumber;
  final VoidCallback onToggleAvailability;
  final bool updatingAvailability;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight + 12;
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: meta.gradient)),
      child: Stack(
        children: [
          Positioned(
            right: -52,
            top: 54,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
            ),
          ),
          Positioned(
            left: -70,
            bottom: -90,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, topPadding, 20, 86),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 10)),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(_initials(name), style: TextStyle(color: meta.color, fontWeight: FontWeight.w800, fontSize: 28)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meta.label.toUpperCase(),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontWeight: FontWeight.w700, letterSpacing: 1.05, fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _HeroChip(label: email.isEmpty ? 'No email provided' : email, icon: Icons.email_rounded),
                              if (licenseNumber.isNotEmpty) _HeroChip(label: 'Lic. $licenseNumber', icon: Icons.badge_rounded),
                              _HeroChip(label: isAvailable ? 'Available' : 'Off duty', icon: isAvailable ? Icons.check_circle_rounded : Icons.pause_circle_rounded, accent: isAvailable ? const Color(0xFF10B981) : const Color(0xFFCBD5E1)),
                              _HeroChip(label: employmentStatus.replaceAll('_', ' '), icon: Icons.work_history_rounded),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _HeroMetric(label: 'Rating', value: rating.toStringAsFixed(1), color: Colors.amber.shade700, icon: Icons.star_rounded)),
                    const SizedBox(width: 10),
                    Expanded(child: _HeroMetric(label: 'Patients', value: '$activePatients', color: const Color(0xFF0D9488), icon: Icons.groups_rounded)),
                    const SizedBox(width: 10),
                    Expanded(child: _HeroMetric(label: 'Visits', value: '$totalVisits', color: const Color(0xFF4F46E5), icon: Icons.calendar_month_rounded)),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: meta.color),
                  onPressed: updatingAvailability ? null : onToggleAvailability,
                  icon: updatingAvailability
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(isAvailable ? Icons.pause_circle_rounded : Icons.check_circle_rounded),
                  label: Text(isAvailable ? 'Set off duty' : 'Set available'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.caregiver,
    required this.user,
    required this.specialties,
    required this.certifications,
    required this.meta,
  });

  final Map<String, dynamic> caregiver;
  final Map<String, dynamic> user;
  final List<String> specialties;
  final List<Map<String, dynamic>> certifications;
  final _CaregiverMeta meta;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bio = caregiver['bio']?.toString() ?? '';
    final isIndependent = caregiver['is_independent'] == true;
    final hourlyRate = caregiver['hourly_rate'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        _SurfaceSection(
          title: 'Profile details',
          icon: Icons.account_box_rounded,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DetailPill(label: 'Category', value: meta.label, color: meta.color),
              _DetailPill(label: 'Employment', value: (caregiver['employment_status'] ?? 'active').toString().replaceAll('_', ' '), color: _employmentColor((caregiver['employment_status'] ?? 'active').toString())),
              _DetailPill(label: 'Engagement', value: isIndependent ? 'Independent' : 'Employee', color: isIndependent ? const Color(0xFFD97706) : const Color(0xFF2563EB)),
              if (caregiver['hire_date'] != null) _DetailPill(label: 'Hire date', value: caregiver['hire_date'].toString(), color: const Color(0xFF0D9488)),
              if (hourlyRate != null) _DetailPill(label: 'Hourly rate', value: 'KSh $hourlyRate', color: const Color(0xFF7C3AED)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SurfaceSection(
          title: 'Contact',
          icon: Icons.contact_phone_rounded,
          child: Column(
            children: [
              if ((user['phone'] ?? '').toString().isNotEmpty) _ProfileLine(icon: Icons.phone_rounded, label: 'Phone', value: user['phone'].toString()),
              if ((user['email'] ?? '').toString().isNotEmpty) _ProfileLine(icon: Icons.email_rounded, label: 'Email', value: user['email'].toString()),
              if ((caregiver['license_number'] ?? '').toString().isNotEmpty) _ProfileLine(icon: Icons.badge_rounded, label: 'License', value: caregiver['license_number'].toString()),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (bio.isNotEmpty)
          Column(
            children: [
              _SurfaceSection(
                title: 'About',
                icon: Icons.info_outline_rounded,
                child: Text(bio, style: TextStyle(color: cs.onSurfaceVariant, height: 1.5)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        _SurfaceSection(
          title: 'Specialties & skills',
          icon: Icons.workspace_premium_rounded,
          child: specialties.isEmpty
              ? const _TabEmptyState(
                  icon: Icons.star_outline_rounded,
                  title: 'No specialties listed',
                  subtitle: 'Add caregiver skills in the enrolment or edit workflow.',
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: specialties.map((skill) => _SkillChip(label: skill, color: meta.color)).toList(),
                ),
        ),
        const SizedBox(height: 12),
        _SurfaceSection(
          title: 'Certifications',
          icon: Icons.verified_rounded,
          child: certifications.isEmpty
              ? const _TabEmptyState(
                  icon: Icons.verified_user_outlined,
                  title: 'No certifications recorded',
                  subtitle: 'Professional certifications will appear here when they are added.',
                )
              : Column(
                  children: certifications.map((certification) {
                    final name = certification['name']?.toString() ?? 'Certification';
                    final issuer = certification['issuer']?.toString() ?? '';
                    final year = certification['year']?.toString() ?? '';
                    final detail = [issuer, year].where((item) => item.isNotEmpty).join(' • ');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(backgroundColor: meta.color.withValues(alpha: 0.12), child: Icon(Icons.verified_rounded, color: meta.color)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  if (detail.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text(detail, style: TextStyle(color: cs.onSurfaceVariant)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _VisitsTab extends StatelessWidget {
  const _VisitsTab({required this.visits});

  final List<Map<String, dynamic>> visits;

  @override
  Widget build(BuildContext context) {
    if (visits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: _TabEmptyState(
          icon: Icons.calendar_today_rounded,
          title: 'No upcoming visits',
          subtitle: 'Scheduled home visits will appear here once the caregiver is assigned.',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: visits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final visit = visits[index];
        final patientName = visit['patient_name']?.toString() ?? 'Patient #${visit['patient'] ?? '—'}';
        final status = visit['status']?.toString() ?? 'scheduled';
        return _SurfaceSection(
          title: patientName,
          icon: Icons.calendar_month_rounded,
          compactHeader: true,
          trailing: _DetailPill(label: 'Status', value: status.replaceAll('_', ' '), color: _visitStatusColor(status)),
          child: Column(
            children: [
              _ProfileLine(icon: Icons.schedule_rounded, label: 'Start', value: _formatDateTime(visit['start_at']?.toString())),
              if ((visit['end_at'] ?? '').toString().isNotEmpty) _ProfileLine(icon: Icons.timelapse_rounded, label: 'End', value: _formatDateTime(visit['end_at']?.toString())),
              _ProfileLine(icon: Icons.flag_rounded, label: 'Status', value: status.replaceAll('_', ' ')),
              if ((visit['notes'] ?? '').toString().isNotEmpty) _ProfileLine(icon: Icons.notes_rounded, label: 'Notes', value: visit['notes'].toString()),
            ],
          ),
        );
      },
    );
  }
}

class _PatientsTab extends StatelessWidget {
  const _PatientsTab({required this.patients});

  final List<Map<String, dynamic>> patients;

  @override
  Widget build(BuildContext context) {
    if (patients.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: _TabEmptyState(
          icon: Icons.groups_rounded,
          title: 'No active patients',
          subtitle: 'Patient assignments will appear here when this caregiver is linked to the care roster.',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      itemCount: patients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final patient = patients[index];
        final user = patient['user'] as Map<String, dynamic>? ?? const {};
        final name = _patientName(patient);
        final risk = patient['risk_level']?.toString();
        final phone = user['phone']?.toString() ?? '';
        final address = patient['address']?.toString() ?? '';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/homecare/patients/${patient['id']}'),
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.22)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.12),
                    child: Text(_initials(name), style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        if (phone.isNotEmpty)
                          Text(phone, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        if (address.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(address, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ),
                        if (risk != null && risk.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _DetailPill(label: 'Risk', value: risk, color: _riskColor(risk)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SurfaceSection extends StatelessWidget {
  const _SurfaceSection({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.compactHeader = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final bool compactHeader;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compactHeader ? 34 : 40,
                height: compactHeader ? 34 : 40,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.primary, size: compactHeader ? 18 : 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.icon, this.accent});

  final String label;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent ?? Colors.white),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value, required this.color, required this.icon});

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18))),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w700, fontSize: 12)),
        ],
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.82), fontSize: 11.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabEmptyState extends StatelessWidget {
  const _TabEmptyState({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: cs.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, height: 1.45)),
          ],
        ),
      ),
    );
  }
}

class _CaregiverMeta {
  const _CaregiverMeta({required this.label, required this.color, required this.gradient});

  final String label;
  final Color color;
  final List<Color> gradient;
}

_CaregiverMeta _caregiverMeta(String? category) {
  switch (category) {
    case 'nurse':
      return const _CaregiverMeta(
        label: 'Nurse',
        color: Color(0xFF4F46E5),
        gradient: [Color(0xFF4338CA), Color(0xFF6366F1), Color(0xFF818CF8)],
      );
    case 'hca':
      return const _CaregiverMeta(
        label: 'Health Care Assistant',
        color: Color(0xFFDB2777),
        gradient: [Color(0xFFBE185D), Color(0xFFDB2777), Color(0xFFF472B6)],
      );
    default:
      return const _CaregiverMeta(
        label: 'Caregiver',
        color: Color(0xFF0D9488),
        gradient: [Color(0xFF0F766E), Color(0xFF14B8A6), Color(0xFF2DD4BF)],
      );
  }
}

Color _employmentColor(String status) {
  switch (status) {
    case 'active':
      return const Color(0xFF16A34A);
    case 'on_leave':
      return const Color(0xFFD97706);
    case 'suspended':
      return const Color(0xFFDC2626);
    case 'terminated':
      return const Color(0xFF7C2D12);
    default:
      return const Color(0xFF64748B);
  }
}

Color _visitStatusColor(String status) {
  switch (status) {
    case 'completed':
      return const Color(0xFF16A34A);
    case 'in_progress':
      return const Color(0xFF2563EB);
    case 'missed':
      return const Color(0xFFDC2626);
    case 'cancelled':
      return const Color(0xFF7C3AED);
    default:
      return const Color(0xFF0D9488);
  }
}

Color _riskColor(String risk) {
  switch (risk.toLowerCase()) {
    case 'high':
    case 'critical':
      return const Color(0xFFDC2626);
    case 'medium':
      return const Color(0xFFD97706);
    default:
      return const Color(0xFF16A34A);
  }
}

String _caregiverName(Map<String, dynamic> caregiver) {
  final user = caregiver['user'] as Map<String, dynamic>? ?? const {};
  final fullName = (user['full_name'] ?? '').toString().trim();
  if (fullName.isNotEmpty) return fullName;
  final joined = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
  if (joined.isNotEmpty) return joined;
  return user['email']?.toString() ?? 'Caregiver';
}

String _patientName(Map<String, dynamic> patient) {
  final user = patient['user'] as Map<String, dynamic>? ?? const {};
  final fullName = (user['full_name'] ?? '').toString().trim();
  if (fullName.isNotEmpty) return fullName;
  final joined = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
  if (joined.isNotEmpty) return joined;
  return user['email']?.toString() ?? 'Patient';
}

String _initials(String value) {
  final parts = value.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
}

String _formatDateTime(String? iso) {
  if (iso == null || iso.isEmpty) return 'Not scheduled';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '${parsed.year}-$month-$day • $hour:$minute';
}
