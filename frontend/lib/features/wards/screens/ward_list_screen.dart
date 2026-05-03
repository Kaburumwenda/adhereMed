import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/ward_model.dart';
import '../repository/ward_repository.dart';

class WardListScreen extends ConsumerStatefulWidget {
  const WardListScreen({super.key});

  @override
  ConsumerState<WardListScreen> createState() => _WardListScreenState();
}

class _WardListScreenState extends ConsumerState<WardListScreen>
    with SingleTickerProviderStateMixin {
  final _repo = WardRepository();
  late TabController _tabController;

  // Ward tab
  PaginatedResponse<Ward>? _wardData;
  bool _wardLoading = true;
  String? _wardError;
  int _wardPage = 1;
  String _wardSearch = '';
  String _wardTypeFilter = 'all';

  // Admission tab
  PaginatedResponse<Admission>? _admissionData;
  bool _admissionLoading = true;
  String? _admissionError;
  int _admissionPage = 1;
  String _admissionSearch = '';
  String _admissionStatusFilter = 'all';

  static const _wardTypes = [
    'all', 'general', 'icu', 'maternity', 'pediatric',
    'surgical', 'emergency', 'private',
  ];
  static const _admissionStatuses = ['all', 'active', 'discharged', 'transferred'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadWards();
    _loadAdmissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadWards() async {
    setState(() { _wardLoading = true; _wardError = null; });
    try {
      final result = await _repo.getWards(
        page: _wardPage,
        search: _wardSearch.isEmpty ? null : _wardSearch,
        type: _wardTypeFilter == 'all' ? null : _wardTypeFilter,
      );
      setState(() { _wardData = result; _wardLoading = false; });
    } catch (e) {
      setState(() { _wardError = e.toString(); _wardLoading = false; });
    }
  }

  Future<void> _loadAdmissions() async {
    setState(() { _admissionLoading = true; _admissionError = null; });
    try {
      final result = await _repo.getAdmissions(
        page: _admissionPage,
        search: _admissionSearch.isEmpty ? null : _admissionSearch,
        status: _admissionStatusFilter == 'all' ? null : _admissionStatusFilter,
      );
      setState(() { _admissionData = result; _admissionLoading = false; });
    } catch (e) {
      setState(() { _admissionError = e.toString(); _admissionLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Compute KPIs from loaded data
    final wards = _wardData?.results ?? [];
    final totalWards = _wardData?.count ?? 0;
    final totalAvailable = wards.fold<int>(
        0, (sum, w) => sum + (w.availableBeds ?? 0));
    final activeAdmissions = _admissionData?.results
            .where((a) => a.status == 'active')
            .length ??
        0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gradient header ──
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.55, 1.0],
                colors: [
                  Color(0xFF064E3B),
                  Color(0xFF0F766E),
                  Color(0xFF1D4ED8)
                ],
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
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.local_hotel_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ward Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage wards, beds & patient admissions',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // KPI pills
                Wrap(
                  spacing: 10,
                  children: [
                    _HeaderKpi(
                        icon: Icons.domain_rounded,
                        value: '$totalWards',
                        label: 'Wards'),
                    _HeaderKpi(
                        icon: Icons.bed_rounded,
                        value: '$totalAvailable',
                        label: 'Available'),
                    _HeaderKpi(
                        icon: Icons.person_rounded,
                        value: '$activeAdmissions',
                        label: 'Admitted'),
                  ],
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: () => context.push('/wards/new'),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Ward'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F766E),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Tabs ──
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicator: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13.5),
              unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13.5),
              tabs: const [
                Tab(text: 'Wards & Beds'),
                Tab(text: 'Admissions'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWardsTab(),
                _buildAdmissionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Wards Tab ───
  Widget _buildWardsTab() {
    return Column(
      children: [
        // Search + chip filters
        Row(
          children: [
            Expanded(
              child: SearchField(
                hintText: 'Search wards...',
                onChanged: (v) {
                  _wardSearch = v;
                  _wardPage = 1;
                  _loadWards();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _wardTypes.map((t) {
              final selected = _wardTypeFilter == t;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(t == 'all' ? 'All' : t.toUpperCase()),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _wardTypeFilter = t);
                    _wardPage = 1;
                    _loadWards();
                  },
                  selectedColor:
                      AppColors.primary.withValues(alpha: 0.12),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color:
                        selected ? AppColors.primary : AppColors.textSecondary,
                  ),
                  side: BorderSide(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.border,
                  ),
                  backgroundColor: AppColors.surface,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _wardLoading
              ? const LoadingWidget()
              : _wardError != null
                  ? app_error.AppErrorWidget(
                      message: _wardError!, onRetry: _loadWards)
                  : _wardData == null || _wardData!.results.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.local_hotel_outlined,
                          title: 'No wards found',
                          subtitle: 'Add a ward to get started.',
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: LayoutBuilder(builder: (ctx, c) {
                                final cols = c.maxWidth > 1000
                                    ? 3
                                    : c.maxWidth > 640
                                        ? 2
                                        : 1;
                                return GridView.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 2.4,
                                  ),
                                  itemCount: _wardData!.results.length,
                                  itemBuilder: (ctx, i) =>
                                      _WardCard(
                                    ward: _wardData!.results[i],
                                    onView: () => context
                                        .push('/wards/${_wardData!.results[i].id}'),
                                    onEdit: () => context.push(
                                        '/wards/${_wardData!.results[i].id}/edit'),
                                    onDelete: () =>
                                        _deleteWard(_wardData!.results[i]),
                                  ),
                                );
                              }),
                            ),
                            _pagination(
                                _wardData!,
                                _wardPage,
                                (p) {
                                  _wardPage = p;
                                  _loadWards();
                                }),
                          ],
                        ),
        ),
      ],
    );
  }

  // ─── Admissions Tab ───
  Widget _buildAdmissionsTab() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SearchField(
                hintText: 'Search admissions...',
                onChanged: (v) {
                  _admissionSearch = v;
                  _admissionPage = 1;
                  _loadAdmissions();
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: _admissionStatusFilter,
                decoration:
                    const InputDecoration(labelText: 'Status', isDense: true),
                items: _admissionStatuses
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(
                              s == 'all' ? 'All Statuses' : s.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (v) {
                  _admissionStatusFilter = v ?? 'all';
                  _admissionPage = 1;
                  _loadAdmissions();
                },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => context.push('/wards/admissions/new'),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('New Admission'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _admissionLoading
              ? const LoadingWidget()
              : _admissionError != null
                  ? app_error.AppErrorWidget(
                      message: _admissionError!, onRetry: _loadAdmissions)
                  : _admissionData == null || _admissionData!.results.isEmpty
                      ? const EmptyStateWidget(
                          icon: Icons.person_add_outlined,
                          title: 'No admissions found',
                          subtitle: 'Admit a patient to get started.',
                        )
                      : Card(
                          child: Column(
                            children: [
                              // Table header
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    _th('Patient', flex: 2),
                                    _th('Bed', flex: 1),
                                    _th('Doctor', flex: 2),
                                    _th('Admitted', flex: 1),
                                    _th('Reason', flex: 2),
                                    _th('Status', flex: 1),
                                    _th('', flex: 1),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: ListView.separated(
                                  itemCount:
                                      _admissionData!.results.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (ctx, i) {
                                    final a =
                                        _admissionData!.results[i];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 34,
                                                  height: 34,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: AppColors.primary
                                                        .withValues(alpha: 0.1),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      (a.patientName ?? 'P')
                                                          .substring(0, 1)
                                                          .toUpperCase(),
                                                      style: TextStyle(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    a.patientName ??
                                                        'ID: ${a.patientId}',
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 13),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              a.bedLabel ?? '-',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      AppColors.textSecondary),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              a.admittingDoctorName ?? '-',
                                              style: const TextStyle(
                                                  fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Text(
                                              a.admissionDate.split('T').first,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              a.reason,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      AppColors.textSecondary),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child:
                                                StatusBadge(status: a.status),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons
                                                          .visibility_outlined,
                                                      size: 18),
                                                  onPressed: () => context.push(
                                                      '/wards/admissions/${a.id}'),
                                                  tooltip: 'View',
                                                  color: AppColors.primary,
                                                ),
                                                IconButton(
                                                  icon: Icon(
                                                      Icons.delete_outline,
                                                      size: 18,
                                                      color: AppColors.error),
                                                  onPressed: () =>
                                                      _deleteAdmission(a),
                                                  tooltip: 'Delete',
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              _pagination(
                                  _admissionData!,
                                  _admissionPage,
                                  (p) {
                                    _admissionPage = p;
                                    _loadAdmissions();
                                  }),
                            ],
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _pagination(PaginatedResponse data, int page,
      void Function(int) onPage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border:
            Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text('${data.count} record${data.count == 1 ? '' : 's'}',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const Spacer(),
          _PaginationButton(
            label: '← Prev',
            enabled: data.previous != null,
            onTap: () => onPage(page - 1),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Page $page',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 8),
          _PaginationButton(
            label: 'Next →',
            enabled: data.next != null,
            onTap: () => onPage(page + 1),
          ),
        ],
      ),
    );
  }

  Widget _th(String label, {int flex = 1}) => Expanded(
        flex: flex,
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
            color: AppColors.textSecondary,
            letterSpacing: 0.4,
          ),
        ),
      );

  Future<void> _deleteWard(Ward w) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Ward'),
        content: Text('Delete "${w.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await _repo.deleteWard(w.id);
        _loadWards();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ward "${w.name}" deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteAdmission(Admission a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Admission'),
        content: Text('Delete admission for ${a.patientName ?? 'this patient'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await _repo.deleteAdmission(a.id);
        _loadAdmissions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Admission deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Header KPI pill
// ────────────────────────────────────────────────────────────────────────────
class _HeaderKpi extends StatelessWidget {
  const _HeaderKpi({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF5EEAD4), size: 15),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      height: 1.1)),
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                      height: 1.2)),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Ward card (grid item)
// ────────────────────────────────────────────────────────────────────────────
class _WardCard extends StatelessWidget {
  const _WardCard({
    required this.ward,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });
  final Ward ward;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _typeColors = {
    'icu': Color(0xFFEF4444),
    'emergency': Color(0xFFF97316),
    'maternity': Color(0xFFEC4899),
    'surgical': Color(0xFF8B5CF6),
    'pediatric': Color(0xFF06B6D4),
    'private': Color(0xFF6366F1),
    'general': Color(0xFF0D9488),
  };

  @override
  Widget build(BuildContext context) {
    final typeColor =
        _typeColors[ward.type.toLowerCase()] ?? AppColors.primary;
    final available = ward.availableBeds ?? 0;
    final capacity = ward.capacity;
    final pct = capacity > 0 ? (available / capacity).clamp(0.0, 1.0) : 0.0;
    final occupied = capacity - available;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: name + type badge + actions
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.local_hotel_rounded,
                        color: typeColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ward.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ward.type.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: typeColor),
                              ),
                            ),
                            if (ward.floor != null) ...[
                              const SizedBox(width: 6),
                              Text('Floor ${ward.floor}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status dot
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ward.isActive
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Occupancy bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Occupancy',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$occupied',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary),
                        ),
                        TextSpan(
                          text: '/$capacity beds',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: capacity > 0
                      ? (occupied / capacity).clamp(0.0, 1.0)
                      : 0,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    occupied == capacity
                        ? AppColors.error
                        : occupied > capacity * 0.75
                            ? AppColors.warning
                            : AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Bottom row: available + rate + actions
              Row(
                children: [
                  Icon(Icons.bed_rounded,
                      size: 13,
                      color: pct > 0 ? AppColors.success : AppColors.error),
                  const SizedBox(width: 4),
                  Text(
                    '$available available',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: pct > 0 ? AppColors.success : AppColors.error),
                  ),
                  const Spacer(),
                  Text(
                    '\$${ward.dailyRate.toStringAsFixed(0)}/day',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  _CardActionButton(
                      icon: Icons.edit_outlined,
                      color: AppColors.primary,
                      tooltip: 'Edit',
                      onTap: onEdit),
                  _CardActionButton(
                      icon: Icons.delete_outline,
                      color: AppColors.error,
                      tooltip: 'Delete',
                      onTap: onDelete),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Pagination button
// ────────────────────────────────────────────────────────────────────────────
class _PaginationButton extends StatelessWidget {
  const _PaginationButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: enabled ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
