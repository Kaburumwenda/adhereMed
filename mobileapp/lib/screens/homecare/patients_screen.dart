import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/common.dart';
import 'providers.dart';

// ─── Filter providers ────────────────────────────────────
final _riskFilterProvider = StateProvider<String>((ref) => 'all');
final _statusFilterProvider = StateProvider<String>((ref) => 'all');

class HomecarePatientsScreen extends ConsumerStatefulWidget {
  const HomecarePatientsScreen({super.key});

  @override
  ConsumerState<HomecarePatientsScreen> createState() => _HomecarePatientsScreenState();
}

class _HomecarePatientsScreenState extends ConsumerState<HomecarePatientsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(homecarePatientsProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final riskFilter = ref.watch(_riskFilterProvider);
    final statusFilter = ref.watch(_statusFilterProvider);
    final searchText = ref.watch(homecarePatientSearchProvider);

    return Scaffold(
      body: patients.when(
        loading: () => const LoadingShimmer(lines: 8),
        error: (e, _) => ErrorRetry(
          message: 'Failed to load patients',
          onRetry: () => ref.invalidate(homecarePatientsProvider),
        ),
        data: (list) {
          // Compute stats
          final total = list.length;
          final active = list.where((p) => p['is_active'] == true).length;
          final high = list.where((p) => p['risk_level'] == 'high').length;
          final critical = list.where((p) => p['risk_level'] == 'critical').length;

          // Apply filters
          final filtered = list.where((p) {
            if (riskFilter != 'all' && p['risk_level'] != riskFilter) return false;
            if (statusFilter == 'active' && p['is_active'] != true) return false;
            if (statusFilter == 'closed' && p['is_active'] != false) return false;
            if (searchText.isNotEmpty) {
              final user = p['user'] as Map<String, dynamic>? ?? {};
              final hay = [
                user['full_name'] ?? '',
                '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}',
                user['email'] ?? '',
                p['medical_record_number'] ?? '',
                p['primary_diagnosis'] ?? '',
                p['assigned_caregiver_name'] ?? '',
              ].join(' ').toLowerCase();
              return hay.contains(searchText.toLowerCase());
            }
            return true;
          }).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(homecarePatientsProvider),
            child: CustomScrollView(
              slivers: [
                // ── Hero Header ──
                SliverToBoxAdapter(
                  child: _HeroHeader(
                    total: total,
                    active: active,
                    critical: critical,
                    isDark: isDark,
                    cs: cs,
                  ),
                ),

                // ── KPI Strip ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      children: [
                        Expanded(child: _StatTile(label: 'Total', value: '$total', icon: Icons.people_alt_rounded, color: const Color(0xFF0D9488))),
                        const SizedBox(width: 8),
                        Expanded(child: _StatTile(label: 'Active', value: '$active', icon: Icons.check_circle_rounded, color: const Color(0xFF10B981))),
                        const SizedBox(width: 8),
                        Expanded(child: _StatTile(label: 'High Risk', value: '$high', icon: Icons.shield_rounded, color: const Color(0xFFF59E0B))),
                        const SizedBox(width: 8),
                        Expanded(child: _StatTile(label: 'Critical', value: '$critical', icon: Icons.warning_rounded, color: const Color(0xFFEF4444))),
                      ],
                    ),
                  ),
                ),

                // ── Search & Filters ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      children: [
                        // Search field
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search by name, MRN, email…',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      ref.read(homecarePatientSearchProvider.notifier).state = '';
                                      setState(() {});
                                    },
                                  )
                                : null,
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          onChanged: (v) {
                            ref.read(homecarePatientSearchProvider.notifier).state = v;
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 12),
                        // Filter chips
                        Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _FilterChip(
                                      label: 'All Risks',
                                      icon: Icons.shield_outlined,
                                      isSelected: riskFilter == 'all',
                                      onTap: () => ref.read(_riskFilterProvider.notifier).state = 'all',
                                    ),
                                    _FilterChip(
                                      label: 'Low',
                                      color: Colors.green,
                                      isSelected: riskFilter == 'low',
                                      onTap: () => ref.read(_riskFilterProvider.notifier).state = 'low',
                                    ),
                                    _FilterChip(
                                      label: 'Medium',
                                      color: Colors.amber.shade700,
                                      isSelected: riskFilter == 'medium',
                                      onTap: () => ref.read(_riskFilterProvider.notifier).state = 'medium',
                                    ),
                                    _FilterChip(
                                      label: 'High',
                                      color: Colors.orange,
                                      isSelected: riskFilter == 'high',
                                      onTap: () => ref.read(_riskFilterProvider.notifier).state = 'high',
                                    ),
                                    _FilterChip(
                                      label: 'Critical',
                                      color: Colors.red,
                                      isSelected: riskFilter == 'critical',
                                      onTap: () => ref.read(_riskFilterProvider.notifier).state = 'critical',
                                    ),
                                    const SizedBox(width: 12),
                                    _FilterChip(
                                      label: 'Active',
                                      icon: Icons.check_circle_outline,
                                      color: Colors.green,
                                      isSelected: statusFilter == 'active',
                                      onTap: () => ref.read(_statusFilterProvider.notifier).state =
                                          statusFilter == 'active' ? 'all' : 'active',
                                    ),
                                    _FilterChip(
                                      label: 'Closed',
                                      icon: Icons.cancel_outlined,
                                      color: Colors.grey,
                                      isSelected: statusFilter == 'closed',
                                      onTap: () => ref.read(_statusFilterProvider.notifier).state =
                                          statusFilter == 'closed' ? 'all' : 'closed',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Results count ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Text(
                          '${filtered.length} patient${filtered.length == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
                        ),
                        const Spacer(),
                        if (riskFilter != 'all' || statusFilter != 'all')
                          TextButton.icon(
                            onPressed: () {
                              ref.read(_riskFilterProvider.notifier).state = 'all';
                              ref.read(_statusFilterProvider.notifier).state = 'all';
                            },
                            icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                            label: const Text('Clear filters', style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Empty State ──
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 72, color: cs.outlineVariant),
                          const SizedBox(height: 12),
                          Text(
                            'No patients found',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            searchText.isNotEmpty || riskFilter != 'all' || statusFilter != 'all'
                                ? 'Try clearing filters or adjusting your search.'
                                : 'Enrol your first patient to get started.',
                            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Patient cards ──
                if (filtered.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _PatientCard(patient: filtered[i], cs: cs)
                            .animate(delay: Duration(milliseconds: 40 * (i < 10 ? i : 0)))
                            .fadeIn(duration: 250.ms)
                            .slideY(begin: 0.03, duration: 250.ms),
                        childCount: filtered.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/homecare/patients/new');
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Enrol'),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Hero Header
// ═══════════════════════════════════════════════════════════
class _HeroHeader extends StatelessWidget {
  final int total;
  final int active;
  final int critical;
  final bool isDark;
  final ColorScheme cs;

  const _HeroHeader({
    required this.total,
    required this.active,
    required this.critical,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 24),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOMECARE · PATIENTS',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Patients in care',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$total enrolled · $active active · $critical critical',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ═══════════════════════════════════════════════════════════
// Stat Tile (KPI strip item)
// ═══════════════════════════════════════════════════════════
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Filter Chip
// ═══════════════════════════════════════════════════════════
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, this.icon, this.color, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: isSelected ? c.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? c : Theme.of(context).dividerColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: isSelected ? c : Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? c : Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Patient Card (rich, matching web grid card)
// ═══════════════════════════════════════════════════════════
class _PatientCard extends StatelessWidget {
  final dynamic patient;
  final ColorScheme cs;

  const _PatientCard({required this.patient, required this.cs});

  @override
  Widget build(BuildContext context) {
    final user = patient['user'] as Map<String, dynamic>? ?? {};
    final name = _patientName(user);
    final initials = _initials(name);
    final mrn = patient['medical_record_number'] ?? '';
    final riskLevel = patient['risk_level'] ?? 'low';
    final isActive = patient['is_active'] ?? true;
    final diagnosis = patient['primary_diagnosis'] ?? '';
    final String caregiverName;
    if (patient['assigned_caregiver_name'] != null) {
      caregiverName = patient['assigned_caregiver_name'];
    } else if (patient['assigned_caregiver'] is Map) {
      caregiverName = (patient['assigned_caregiver']['user']?['full_name'] ?? '') as String;
    } else {
      caregiverName = '';
    }
    final additionalCaregivers = patient['additional_caregivers_detail'] as List? ?? [];
    final adherenceRate = patient['adherence_rate'] as num?;
    final age = patient['age'] as num?;
    final gender = patient['gender'] ?? '';
    final openEscalations = patient['open_escalations'] as num?;

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

    final Color adherenceColor;
    if (adherenceRate == null) {
      adherenceColor = cs.onSurfaceVariant;
    } else if (adherenceRate >= 85) {
      adherenceColor = Colors.green;
    } else if (adherenceRate >= 60) {
      adherenceColor = Colors.orange;
    } else {
      adherenceColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/homecare/patients/${patient['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: avatar + name + risk chip ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: riskColor.withValues(alpha: 0.12),
                    child: Text(
                      initials,
                      style: TextStyle(color: riskColor, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mrn,
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      riskLevel.toUpperCase(),
                      style: TextStyle(fontSize: 10, color: riskColor, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Info rows ──
              if (diagnosis.isNotEmpty)
                _CardInfoRow(icon: Icons.medical_information_rounded, text: diagnosis, color: cs.onSurfaceVariant),
              if (caregiverName.isNotEmpty)
                _CardInfoRow(
                  icon: Icons.medical_services_rounded,
                  text: caregiverName,
                  color: cs.primary,
                  trailing: additionalCaregivers.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text('+${additionalCaregivers.length}', style: const TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.w700)),
                        )
                      : null,
                ),
              if (age != null || gender.isNotEmpty)
                _CardInfoRow(
                  icon: Icons.person_rounded,
                  text: [if (age != null) '$age yrs', if (gender.isNotEmpty) gender].join(' · '),
                  color: cs.onSurfaceVariant,
                ),

              // ── Bottom stats row ──
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // Adherence
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Adherence', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(
                          adherenceRate != null ? '${adherenceRate.toInt()}%' : '—',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: adherenceColor),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    // Status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isActive ? Colors.green : Colors.grey).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Closed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isActive ? Colors.green : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Escalations badge
                    if (openEscalations != null && openEscalations > 0)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                            const SizedBox(width: 4),
                            Text('$openEscalations', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.red)),
                          ],
                        ),
                      ),
                    // Arrow
                    Icon(Icons.chevron_right_rounded, color: cs.outlineVariant),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'P';
  }
}

// ═══════════════════════════════════════════════════════════
// Card Info Row
// ═══════════════════════════════════════════════════════════
class _CardInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Widget? trailing;

  const _CardInfoRow({required this.icon, required this.text, required this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
