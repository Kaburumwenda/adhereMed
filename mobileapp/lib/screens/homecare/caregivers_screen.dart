import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../widgets/common.dart';
import 'providers.dart';

class HomecareCaregiversScreen extends ConsumerStatefulWidget {
  const HomecareCaregiversScreen({super.key});

  @override
  ConsumerState<HomecareCaregiversScreen> createState() => _HomecareCaregiversScreenState();
}

class _HomecareCaregiversScreenState extends ConsumerState<HomecareCaregiversScreen> {
  final _searchController = TextEditingController();
  final Set<int> _busyIds = <int>{};

  String _categoryFilter = 'all';
  String? _employmentFilter;
  bool? _availabilityFilter;
  String _viewMode = 'cards';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleAvailability(Map<String, dynamic> caregiver) async {
    final id = caregiver['id'] as int?;
    if (id == null || _busyIds.contains(id)) return;

    setState(() => _busyIds.add(id));
    try {
      await ref.read(dioProvider).post('/homecare/caregivers/$id/toggle_availability/');
      ref.invalidate(homecareCaregiversProvider);
      if (!mounted) return;
      final available = caregiver['is_available'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(available ? 'Caregiver set off duty' : 'Caregiver marked available')),
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
        setState(() => _busyIds.remove(id));
      }
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _categoryFilter = 'all';
      _employmentFilter = null;
      _availabilityFilter = null;
    });
  }

  List<Map<String, dynamic>> _filteredCaregivers(List<Map<String, dynamic>> caregivers) {
    final query = _searchController.text.trim().toLowerCase();
    return caregivers.where((caregiver) {
      if (_categoryFilter != 'all' && caregiver['category'] != _categoryFilter) return false;
      if (_employmentFilter != null && caregiver['employment_status'] != _employmentFilter) return false;
      if (_availabilityFilter != null && caregiver['is_available'] != _availabilityFilter) return false;
      if (query.isEmpty) return true;
      final user = caregiver['user'] as Map<String, dynamic>? ?? const {};
      final blob = [
        user['full_name'],
        user['email'],
        caregiver['license_number'],
        ...(caregiver['specialties'] as List? ?? const []),
      ].whereType<Object>().join(' ').toLowerCase();
      return blob.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final caregiversAsync = ref.watch(homecareCaregiversProvider);

    return Scaffold(
      body: caregiversAsync.when(
        loading: () => const LoadingShimmer(lines: 10),
        error: (error, _) => ErrorRetry(
          message: 'Failed to load caregivers',
          onRetry: () => ref.invalidate(homecareCaregiversProvider),
        ),
        data: (raw) {
          final caregivers = raw
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList(growable: false);
          final filtered = _filteredCaregivers(caregivers);
          final width = MediaQuery.of(context).size.width;
          final crossAxisCount = width >= 1220 ? 4 : width >= 900 ? 3 : width >= 640 ? 2 : 1;
          final counts = _CaregiverCounts.fromList(caregivers);
          final hasFilters = _categoryFilter != 'all' || _employmentFilter != null || _availabilityFilter != null || _searchController.text.isNotEmpty;
          final cs = Theme.of(context).colorScheme;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(homecareCaregiversProvider);
              await ref.read(homecareCaregiversProvider.future);
            },
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _CaregiverHero(
                    counts: counts,
                    onAdd: () => context.push('/homecare/caregivers/new'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _FilterPanel(
                      searchController: _searchController,
                      categoryFilter: _categoryFilter,
                      employmentFilter: _employmentFilter,
                      availabilityFilter: _availabilityFilter,
                      viewMode: _viewMode,
                      hasFilters: hasFilters,
                      onSearchChanged: () => setState(() {}),
                      onCategoryChanged: (value) => setState(() => _categoryFilter = value),
                      onEmploymentChanged: (value) => setState(() => _employmentFilter = value),
                      onAvailabilityChanged: (value) => setState(() => _availabilityFilter = value),
                      onViewModeChanged: (value) => setState(() => _viewMode = value),
                      onClear: _clearFilters,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Row(
                      children: [
                        Text(
                          '${filtered.length} caregiver${filtered.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        if (_viewMode == 'cards')
                          _InfoChip(
                            label: crossAxisCount == 1 ? 'Single column' : '$crossAxisCount-column layout',
                            color: const Color(0xFF0D9488),
                          )
                        else
                          _InfoChip(label: 'Compact view', color: const Color(0xFF6366F1)),
                      ],
                    ),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: EmptyState(
                          icon: Icons.group_off_rounded,
                          title: 'No caregivers match your filters',
                          subtitle: hasFilters
                              ? 'Clear or adjust the search and filter controls to broaden the roster.'
                              : 'Add a caregiver to start building your homecare team.',
                        ),
                      ),
                    ),
                  )
                else if (_viewMode == 'cards')
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: crossAxisCount == 1
                        ? SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _CaregiverShowcaseCard(
                                  caregiver: filtered[index],
                                  busy: _busyIds.contains(filtered[index]['id']),
                                  onToggleAvailability: () => _toggleAvailability(filtered[index]),
                                ),
                              ),
                              childCount: filtered.length,
                            ),
                          )
                        : SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _CaregiverShowcaseCard(
                                caregiver: filtered[index],
                                busy: _busyIds.contains(filtered[index]['id']),
                                onToggleAvailability: () => _toggleAvailability(filtered[index]),
                              ),
                              childCount: filtered.length,
                            ),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              mainAxisExtent: 332,
                            ),
                          ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CaregiverCompactCard(
                            caregiver: filtered[index],
                            busy: _busyIds.contains(filtered[index]['id']),
                            onToggleAvailability: () => _toggleAvailability(filtered[index]),
                            cs: cs,
                          ),
                        ),
                        childCount: filtered.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CaregiverHero extends StatelessWidget {
  const _CaregiverHero({required this.counts, required this.onAdd});

  final _CaregiverCounts counts;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 18, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F766E), Color(0xFF14B8A6), Color(0xFF2DD4BF)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
                ),
                child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOMECARE · TEAM',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Caregivers',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Field nurses and health-care assistants delivering care in patients\' homes.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroStatChip(icon: Icons.groups_rounded, label: '${counts.total} caregivers'),
              _HeroStatChip(icon: Icons.medical_services_rounded, label: '${counts.nurses} nurses'),
              _HeroStatChip(icon: Icons.handshake_rounded, label: '${counts.hcas} HCAs'),
              _HeroStatChip(icon: Icons.check_circle_rounded, label: '${counts.available} available'),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F766E),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Add caregiver'),
          ),
        ],
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.searchController,
    required this.categoryFilter,
    required this.employmentFilter,
    required this.availabilityFilter,
    required this.viewMode,
    required this.hasFilters,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onEmploymentChanged,
    required this.onAvailabilityChanged,
    required this.onViewModeChanged,
    required this.onClear,
  });

  final TextEditingController searchController;
  final String categoryFilter;
  final String? employmentFilter;
  final bool? availabilityFilter;
  final String viewMode;
  final bool hasFilters;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String?> onEmploymentChanged;
  final ValueChanged<bool?> onAvailabilityChanged;
  final ValueChanged<String> onViewModeChanged;
  final VoidCallback onClear;

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
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final searchField = TextField(
                controller: searchController,
                onChanged: (_) => onSearchChanged(),
                decoration: InputDecoration(
                  hintText: 'Search by name, email, license, or specialty',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged();
                          },
                        ),
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              );

              final viewToggle = SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'cards', icon: Icon(Icons.grid_view_rounded), label: Text('Cards')),
                  ButtonSegment(value: 'compact', icon: Icon(Icons.view_agenda_rounded), label: Text('Compact')),
                ],
                selected: {viewMode},
                onSelectionChanged: (selection) => onViewModeChanged(selection.first),
              );

              if (compact) {
                return Column(
                  children: [searchField, const SizedBox(height: 12), viewToggle],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 12),
                  viewToggle,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(label: 'All', selected: categoryFilter == 'all', onTap: () => onCategoryChanged('all')),
              _FilterChip(label: 'Nurses', selected: categoryFilter == 'nurse', onTap: () => onCategoryChanged('nurse'), color: const Color(0xFF4F46E5)),
              _FilterChip(label: 'HCAs', selected: categoryFilter == 'hca', onTap: () => onCategoryChanged('hca'), color: const Color(0xFFDB2777)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(label: 'Any status', selected: employmentFilter == null, onTap: () => onEmploymentChanged(null)),
              _FilterChip(label: 'Active', selected: employmentFilter == 'active', onTap: () => onEmploymentChanged('active'), color: Colors.green),
              _FilterChip(label: 'On leave', selected: employmentFilter == 'on_leave', onTap: () => onEmploymentChanged('on_leave'), color: Colors.orange),
              _FilterChip(label: 'Suspended', selected: employmentFilter == 'suspended', onTap: () => onEmploymentChanged('suspended'), color: Colors.red),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(label: 'Any availability', selected: availabilityFilter == null, onTap: () => onAvailabilityChanged(null)),
              _FilterChip(label: 'Available', selected: availabilityFilter == true, onTap: () => onAvailabilityChanged(true), color: const Color(0xFF0D9488)),
              _FilterChip(label: 'Off duty', selected: availabilityFilter == false, onTap: () => onAvailabilityChanged(false), color: const Color(0xFF64748B)),
              if (hasFilters)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  label: const Text('Clear filters'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CaregiverShowcaseCard extends StatelessWidget {
  const _CaregiverShowcaseCard({
    required this.caregiver,
    required this.busy,
    required this.onToggleAvailability,
  });

  final Map<String, dynamic> caregiver;
  final bool busy;
  final VoidCallback onToggleAvailability;

  @override
  Widget build(BuildContext context) {
    final user = caregiver['user'] as Map<String, dynamic>? ?? const {};
    final name = _caregiverName(caregiver);
    final category = caregiver['category']?.toString();
    final meta = _categoryMeta(category);
    final specialties = ((caregiver['specialties'] as List?) ?? const []).map((item) => item.toString()).where((item) => item.isNotEmpty).take(3).toList();
    final employmentStatus = caregiver['employment_status']?.toString() ?? 'active';
    final isAvailable = caregiver['is_available'] == true;
    final activePatients = (caregiver['active_patients_count'] as num?)?.toInt() ?? 0;
    final rating = (caregiver['rating'] as num?)?.toDouble() ?? 0;
    final visits = (caregiver['total_visits'] as num?)?.toInt() ?? 0;
    final hireDate = caregiver['hire_date']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';
    final license = caregiver['license_number']?.toString() ?? '';
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push('/homecare/caregivers/${caregiver['id']}'),
        child: Ink(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: meta.gradient),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: meta.color.withValues(alpha: 0.12),
                                child: Text(_initials(name), style: TextStyle(color: meta.color, fontWeight: FontWeight.w800, fontSize: 18)),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: isAvailable ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerLow, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _InfoChip(label: meta.label, color: meta.color, icon: meta.icon),
                                    _InfoChip(label: employmentStatus.replaceAll('_', ' '), color: _employmentColor(employmentStatus)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (email.isNotEmpty)
                        _DetailLine(icon: Icons.email_rounded, value: email),
                      if (license.isNotEmpty)
                        _DetailLine(icon: Icons.badge_rounded, value: 'Lic. $license'),
                      if (hireDate.isNotEmpty)
                        _DetailLine(icon: Icons.calendar_month_rounded, value: 'Hired $hireDate'),
                      if (specialties.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: specialties.map((specialty) => _InfoChip(label: specialty, color: cs.secondary, compact: true)).toList(),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: _MetricColumn(label: 'Rating', value: rating.toStringAsFixed(1), color: Colors.amber.shade700)),
                            _VerticalDivider(color: cs.outlineVariant),
                            Expanded(child: _MetricColumn(label: 'Patients', value: '$activePatients', color: const Color(0xFF0D9488))),
                            _VerticalDivider(color: cs.outlineVariant),
                            Expanded(child: _MetricColumn(label: 'Visits', value: '$visits', color: const Color(0xFF4F46E5))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: busy ? null : onToggleAvailability,
                              icon: busy
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : Icon(isAvailable ? Icons.pause_circle_rounded : Icons.check_circle_rounded),
                              label: Text(isAvailable ? 'Set off duty' : 'Set available'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                            onPressed: () => context.push('/homecare/caregivers/${caregiver['id']}'),
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaregiverCompactCard extends StatelessWidget {
  const _CaregiverCompactCard({
    required this.caregiver,
    required this.busy,
    required this.onToggleAvailability,
    required this.cs,
  });

  final Map<String, dynamic> caregiver;
  final bool busy;
  final VoidCallback onToggleAvailability;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final name = _caregiverName(caregiver);
    final meta = _categoryMeta(caregiver['category']?.toString());
    final isAvailable = caregiver['is_available'] == true;
    final activePatients = (caregiver['active_patients_count'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
      ),
      child: ListTile(
        onTap: () => context.push('/homecare/caregivers/${caregiver['id']}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: meta.color.withValues(alpha: 0.12),
          child: Text(_initials(name), style: TextStyle(color: meta.color, fontWeight: FontWeight.w800)),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _InfoChip(label: meta.label, color: meta.color, compact: true),
              _InfoChip(label: '$activePatients patients', color: const Color(0xFF0D9488), compact: true),
              _InfoChip(label: isAvailable ? 'Available' : 'Off duty', color: isAvailable ? const Color(0xFF10B981) : const Color(0xFF64748B), compact: true),
            ],
          ),
        ),
        trailing: IconButton(
          onPressed: busy ? null : onToggleAvailability,
          icon: busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(isAvailable ? Icons.pause_circle_outline_rounded : Icons.check_circle_outline_rounded),
        ),
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0F766E)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? resolved.withValues(alpha: 0.14) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? resolved.withValues(alpha: 0.26) : Colors.transparent),
        ),
        child: Text(label, style: TextStyle(color: selected ? resolved : Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.color, this.icon, this.compact = false});

  final String label;
  final Color color;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 5 : 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: compact ? 11 : 12)),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.86), fontWeight: FontWeight.w600, fontSize: 11.5)),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: color.withValues(alpha: 0.35));
  }
}

class _CaregiverCounts {
  const _CaregiverCounts({required this.total, required this.nurses, required this.hcas, required this.available});

  final int total;
  final int nurses;
  final int hcas;
  final int available;

  factory _CaregiverCounts.fromList(List<Map<String, dynamic>> caregivers) {
    final nurses = caregivers.where((caregiver) => caregiver['category'] == 'nurse').length;
    final hcas = caregivers.where((caregiver) => caregiver['category'] == 'hca').length;
    final available = caregivers.where((caregiver) => caregiver['is_available'] == true).length;
    return _CaregiverCounts(total: caregivers.length, nurses: nurses, hcas: hcas, available: available);
  }
}

class _CategoryMeta {
  const _CategoryMeta({required this.label, required this.color, required this.icon, required this.gradient});

  final String label;
  final Color color;
  final IconData icon;
  final List<Color> gradient;
}

_CategoryMeta _categoryMeta(String? category) {
  switch (category) {
    case 'nurse':
      return const _CategoryMeta(
        label: 'Nurse',
        color: Color(0xFF4F46E5),
        icon: Icons.medical_services_rounded,
        gradient: [Color(0xFF4338CA), Color(0xFF6366F1)],
      );
    case 'hca':
      return const _CategoryMeta(
        label: 'Health Care Assistant',
        color: Color(0xFFDB2777),
        icon: Icons.volunteer_activism_rounded,
        gradient: [Color(0xFFBE185D), Color(0xFFF472B6)],
      );
    default:
      return const _CategoryMeta(
        label: 'Caregiver',
        color: Color(0xFF0D9488),
        icon: Icons.favorite_rounded,
        gradient: [Color(0xFF0F766E), Color(0xFF14B8A6)],
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

String _caregiverName(Map<String, dynamic> caregiver) {
  final user = caregiver['user'] as Map<String, dynamic>? ?? const {};
  final fullName = (user['full_name'] ?? '').toString().trim();
  if (fullName.isNotEmpty) return fullName;
  final joined = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
  if (joined.isNotEmpty) return joined;
  return user['email']?.toString() ?? 'Caregiver';
}

String _initials(String name) {
  final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
}
