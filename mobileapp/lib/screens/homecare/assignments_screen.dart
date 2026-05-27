import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';

class HomecareAssignmentsScreen extends ConsumerStatefulWidget {
  const HomecareAssignmentsScreen({super.key});

  @override
  ConsumerState<HomecareAssignmentsScreen> createState() => _HomecareAssignmentsScreenState();
}

class _HomecareAssignmentsScreenState extends ConsumerState<HomecareAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _caregiverSearchController = TextEditingController();
  final _patientSearchController = TextEditingController();

  List<Map<String, dynamic>> _caregivers = const [];
  List<Map<String, dynamic>> _patients = const [];
  List<Map<String, dynamic>> _shifts = const [];
  Set<int> _initialAssigned = <int>{};
  Set<int> _currentAssigned = <int>{};

  DateTime _sheetDate = DateTime.now();
  int _activeTabIndex = 0;
  String _sheetFilter = 'all';
  String _patientFilter = 'all';
  bool _loadingData = true;
  bool _loadingShifts = false;
  bool _loadingAssignments = false;
  bool _savingAssignments = false;
  String? _error;
  int? _selectedCaregiverId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      final nextIndex = _tabController.index;
      if (!mounted || _activeTabIndex == nextIndex) return;
      setState(() => _activeTabIndex = nextIndex);
    });
    _caregiverSearchController.addListener(_onSearchChanged);
    _patientSearchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _caregiverSearchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _patientSearchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loadingData = true;
      _error = null;
    });
    final dio = ref.read(dioProvider);
    try {
      final results = await Future.wait([
        dio.get('/homecare/caregivers/', queryParameters: {'page_size': 500}),
        dio.get('/homecare/patients/', queryParameters: {'page_size': 1000}),
      ]);
      final caregivers = _listFromResponse(results[0].data);
      final patients = _listFromResponse(results[1].data);
      setState(() {
        _caregivers = caregivers;
        _patients = patients;
        _selectedCaregiverId = _selectedCaregiverId != null && caregivers.any((item) => item['id'] == _selectedCaregiverId)
            ? _selectedCaregiverId
            : caregivers.isNotEmpty
                ? caregivers.first['id'] as int?
                : null;
      });
      await _loadShifts();
      if (_selectedCaregiverId != null) {
        await _loadAssignments(_selectedCaregiverId!);
      }
    } on DioException catch (error) {
      setState(() {
        _error = _extractError(error.response?.data) ?? 'Failed to load assignments data.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingData = false);
      }
    }
  }

  Future<void> _loadShifts() async {
    setState(() => _loadingShifts = true);
    final dio = ref.read(dioProvider);
    final start = DateTime(_sheetDate.year, _sheetDate.month, _sheetDate.day).subtract(const Duration(days: 1));
    final end = DateTime(_sheetDate.year, _sheetDate.month, _sheetDate.day + 14, 23, 59);
    try {
      final response = await dio.get(
        '/homecare/schedules/',
        queryParameters: {
          'page_size': 1000,
          'start_after': start.toIso8601String(),
          'end_before': end.toIso8601String(),
        },
      );
      if (!mounted) return;
      setState(() {
        _shifts = _listFromResponse(response.data);
      });
    } on DioException {
      if (!mounted) return;
      setState(() {
        _shifts = const [];
      });
    } finally {
      if (mounted) {
        setState(() => _loadingShifts = false);
      }
    }
  }

  Future<void> _loadAssignments(int caregiverId) async {
    setState(() => _loadingAssignments = true);
    final dio = ref.read(dioProvider);
    try {
      final response = await dio.get('/homecare/caregivers/$caregiverId/assigned-patients/');
      final assigned = _listFromResponse(response.data).map((item) => item['id'] as int).toSet();
      if (!mounted) return;
      setState(() {
        _initialAssigned = assigned;
        _currentAssigned = Set<int>.from(assigned);
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _extractError(error.response?.data) ?? 'Failed to load patient assignments.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingAssignments = false);
      }
    }
  }

  Future<void> _saveAssignments() async {
    if (_selectedCaregiverId == null || !_isDirty) return;
    setState(() => _savingAssignments = true);
    final caregiverId = _selectedCaregiverId!;
    final ids = _currentAssigned.where((id) {
      final patient = _patientById(id);
      return patient == null || patient['assigned_caregiver'] != caregiverId;
    }).toList();
    final dio = ref.read(dioProvider);
    try {
      final response = await dio.post(
        '/homecare/caregivers/$caregiverId/set-patients/',
        data: {'patient_ids': ids},
      );
      if (!mounted) return;
      final data = response.data as Map<String, dynamic>? ?? const {};
      setState(() {
        _initialAssigned = Set<int>.from(_currentAssigned);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved assignments. +${(data['added'] as List?)?.length ?? 0} added, -${(data['removed'] as List?)?.length ?? 0} removed.',
          ),
        ),
      );
      await _refreshAll();
    } on DioException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_extractError(error.response?.data) ?? 'Failed to save assignments.')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingAssignments = false);
      }
    }
  }

  Future<void> _selectCaregiver(int caregiverId, {bool jumpToAssignments = false}) async {
    if (_selectedCaregiverId == caregiverId) {
      if (jumpToAssignments) _tabController.animateTo(3);
      return;
    }

    if (_isDirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard unsaved assignment changes?'),
          content: const Text(
            'You have pending caregiver assignment changes. Switching caregivers will discard the current draft.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep editing')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard')),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }

    setState(() => _selectedCaregiverId = caregiverId);
    await _loadAssignments(caregiverId);
    if (mounted && jumpToAssignments) {
      _tabController.animateTo(3);
    }
  }

  void _discardAssignmentChanges() {
    setState(() {
      _currentAssigned = Set<int>.from(_initialAssigned);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final selectedCaregiver = _selectedCaregiver;
    final activeTabLabel = const [
      'Shift sheets',
      'Caregiver calendar',
      'Patient calendar',
      'Assignments',
    ][_activeTabIndex];

    return Scaffold(
      backgroundColor: cs.surface,
      bottomNavigationBar: _activeTabIndex == 3 && selectedCaregiver != null && (_isDirty || _savingAssignments)
          ? _AssignmentActionBar(
              caregiverName: _caregiverDisplayName(selectedCaregiver),
              pendingChanges: _pendingChangeCount,
              saving: _savingAssignments,
              onDiscard: _savingAssignments ? null : _discardAssignmentChanges,
              onSave: _savingAssignments || !_isDirty ? null : _saveAssignments,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _AssignmentsHero(
                caregiverCount: _caregivers.length,
                availableNowCount: _availableNowCount,
                engagedNowCount: _engagedNowCount,
                todayShiftsCount: _todayShiftsCount,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _MetricStrip(
                  metrics: [
                    _MetricData(label: 'Caregivers', value: '${_caregivers.length}', color: const Color(0xFF0D9488), icon: Icons.group_rounded),
                    _MetricData(label: 'Available', value: '$_availableNowCount', color: const Color(0xFF10B981), icon: Icons.check_circle_rounded),
                    _MetricData(label: 'Engaged', value: '$_engagedNowCount', color: const Color(0xFFF59E0B), icon: Icons.pending_actions_rounded),
                    _MetricData(label: 'Today', value: '$_todayShiftsCount', color: const Color(0xFF6366F1), icon: Icons.calendar_month_rounded),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _SurfaceCard(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _InfoLozenge(
                        icon: Icons.view_carousel_rounded,
                        label: 'Active view',
                        value: activeTabLabel,
                        color: const Color(0xFF312E81),
                      ),
                      _InfoLozenge(
                        icon: Icons.event_rounded,
                        label: 'Sheet date',
                        value: _formatLongDate(_sheetDate),
                        color: const Color(0xFF6366F1),
                      ),
                      if (selectedCaregiver != null)
                        _InfoLozenge(
                          icon: Icons.person_pin_circle_rounded,
                          label: 'Selected caregiver',
                          value: _caregiverDisplayName(selectedCaregiver),
                          color: const Color(0xFF0D9488),
                        ),
                      if (_activeTabIndex == 3)
                        _InfoLozenge(
                          icon: _isDirty ? Icons.pending_actions_rounded : Icons.check_circle_rounded,
                          label: 'Draft status',
                          value: _isDirty ? '$_pendingChangeCount pending change${_pendingChangeCount == 1 ? '' : 's'}' : 'All synced',
                          color: _isDirty ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                        ),
                      FilledButton.tonalIcon(
                        onPressed: _refreshAll,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh data'),
                      ),
                      if (_activeTabIndex == 0)
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _sheetDate = DateTime.now());
                            _loadShifts();
                          },
                          icon: const Icon(Icons.today_rounded),
                          label: const Text('Jump to today'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_loadingData || _loadingShifts)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              ),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _InlineBanner(
                      key: ValueKey(_error),
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFB45309),
                      background: const Color(0xFFFEF3C7),
                      message: _error!,
                    ),
                  ),
                ),
              ),
            SliverFillRemaining(
              hasScrollBody: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.28)),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelColor: const Color(0xFF0D9488),
                        unselectedLabelColor: cs.onSurfaceVariant,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                        ),
                        splashBorderRadius: BorderRadius.circular(16),
                        tabs: const [
                          Tab(text: 'Shift Sheets', icon: Icon(Icons.assignment_rounded)),
                          Tab(text: 'Caregiver Calendar', icon: Icon(Icons.calendar_month_rounded)),
                          Tab(text: 'Patient Calendar', icon: Icon(Icons.calendar_view_week_rounded)),
                          Tab(text: 'Assignments', icon: Icon(Icons.account_tree_rounded)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildShiftSheetsTab(cs),
                          _buildCaregiverCalendarTab(cs),
                          _buildPatientCalendarTab(cs),
                          _buildPatientAssignmentsTab(cs),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftSheetsTab(ColorScheme cs) {
    final caregivers = _filteredSheetCaregivers;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _SurfaceCard(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final searchField = TextField(
                controller: _caregiverSearchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Search caregivers',
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              );

              final dateNavigator = Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () {
                      setState(() => _sheetDate = _sheetDate.subtract(const Duration(days: 1)));
                      _loadShifts();
                    },
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _sheetDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _sheetDate = picked);
                          _loadShifts();
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.event_rounded, size: 18),
                            const SizedBox(width: 8),
                            Flexible(child: Text(_formatLongDate(_sheetDate), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () {
                      setState(() => _sheetDate = _sheetDate.add(const Duration(days: 1)));
                      _loadShifts();
                    },
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Shift sheet controls', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Choose a focus day, filter the roster, and jump into caregiver management from the active sheet.', style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 14),
                  if (compact) ...[
                    searchField,
                    const SizedBox(height: 12),
                    dateNavigator,
                  ] else
                    Row(
                      children: [
                        Expanded(flex: 5, child: searchField),
                        const SizedBox(width: 12),
                        Expanded(flex: 4, child: dateNavigator),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ChoicePill(
                        label: 'Yesterday',
                        selected: _isSameDay(_sheetDate, DateTime.now().subtract(const Duration(days: 1))),
                        onTap: () {
                          setState(() => _sheetDate = DateTime.now().subtract(const Duration(days: 1)));
                          _loadShifts();
                        },
                      ),
                      _ChoicePill(
                        label: 'Today',
                        selected: _isSameDay(_sheetDate, DateTime.now()),
                        onTap: () {
                          setState(() => _sheetDate = DateTime.now());
                          _loadShifts();
                        },
                        color: const Color(0xFF0D9488),
                      ),
                      _ChoicePill(
                        label: 'Tomorrow',
                        selected: _isSameDay(_sheetDate, DateTime.now().add(const Duration(days: 1))),
                        onTap: () {
                          setState(() => _sheetDate = DateTime.now().add(const Duration(days: 1)));
                          _loadShifts();
                        },
                      ),
                      _TinyChip(label: '${caregivers.length} visible', color: const Color(0xFF312E81)),
                      _TinyChip(label: '${_shifts.where((shift) => _isSameDay(_parseDateTime(shift['start_at']) ?? _sheetDate, _sheetDate)).length} shifts in window', color: const Color(0xFF6366F1)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _ChoicePill(label: 'All caregivers', selected: _sheetFilter == 'all', onTap: () => setState(() => _sheetFilter = 'all')),
                        _ChoicePill(label: 'Available now', selected: _sheetFilter == 'available', onTap: () => setState(() => _sheetFilter = 'available'), color: const Color(0xFF10B981)),
                        _ChoicePill(label: 'Engaged', selected: _sheetFilter == 'engaged', onTap: () => setState(() => _sheetFilter = 'engaged'), color: const Color(0xFFF59E0B)),
                        _ChoicePill(label: 'Live-in', selected: _sheetFilter == 'livein', onTap: () => setState(() => _sheetFilter = 'livein'), color: const Color(0xFF8B5CF6)),
                        _ChoicePill(label: 'Off shift', selected: _sheetFilter == 'off', onTap: () => setState(() => _sheetFilter = 'off'), color: const Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (caregivers.isEmpty)
          _EmptyPanel(
            icon: Icons.assignment_late_rounded,
            title: 'No caregivers match the current sheet',
            subtitle: 'Try a different date or clear the filter to see the full roster.',
          )
        else
          ...caregivers.map((caregiver) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildCaregiverSheetCard(caregiver, cs),
              )),
      ],
    );
  }

  Widget _buildCaregiverCalendarTab(ColorScheme cs) {
    final grouped = _groupShiftsByDate(_upcomingShifts);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _SurfaceCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Caregiver calendar', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Upcoming 14-day operational view grouped by day.', style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _loadShifts,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (grouped.isEmpty)
          _EmptyPanel(
            icon: Icons.calendar_today_rounded,
            title: 'No scheduled shifts in range',
            subtitle: 'Schedules will appear here once visits are assigned for the selected window.',
          )
        else
          ...grouped.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, color: const Color(0xFF6366F1)),
                          const SizedBox(width: 8),
                          Text(entry.key, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const Spacer(),
                          Text('${entry.value.length} shift${entry.value.length == 1 ? '' : 's'}', style: TextStyle(color: cs.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...entry.value.map((shift) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ShiftTimelineTile(shift: shift, accent: _shiftTypeColor(shift['shift_type']?.toString() ?? 'visit')),
                          )),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildPatientCalendarTab(ColorScheme cs) {
    final patientCards = _patients
        .map((patient) => {
              'patient': patient,
              'shifts': _patientUpcomingShifts(patient['id'] as int),
            })
        .where((entry) => (entry['shifts'] as List).isNotEmpty)
        .toList()
      ..sort((a, b) {
        final aShift = (a['shifts'] as List<Map<String, dynamic>>).first;
        final bShift = (b['shifts'] as List<Map<String, dynamic>>).first;
        return _parseDateTime(aShift['start_at'])!.compareTo(_parseDateTime(bShift['start_at'])!);
      });

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _SurfaceCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patient calendar', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Upcoming visits per patient, prioritized by the next encounter.', style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${patientCards.length} active', style: const TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (patientCards.isEmpty)
          _EmptyPanel(
            icon: Icons.people_alt_rounded,
            title: 'No patients with upcoming visits',
            subtitle: 'Once shifts are assigned, each patient timeline will appear here.',
          )
        else
          ...patientCards.map((entry) {
            final patient = entry['patient']! as Map<String, dynamic>;
            final shifts = entry['shifts']! as List<Map<String, dynamic>>;
            final nextShift = shifts.first;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _riskColor(patient['risk_level']?.toString()).withValues(alpha: 0.14),
                          child: Text(_initials(_patientName(patient)), style: TextStyle(color: _riskColor(patient['risk_level']?.toString()), fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_patientName(patient), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(
                                '${patient['medical_record_number'] ?? 'No MRN'}${(patient['primary_diagnosis'] ?? '').toString().isNotEmpty ? ' • ${patient['primary_diagnosis']}' : ''}',
                                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        _StatusBadge(
                          label: patient['risk_level']?.toString().toUpperCase() ?? 'LOW',
                          color: _riskColor(patient['risk_level']?.toString()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded, color: Color(0xFF6366F1)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Next shift ${_formatRelative(_parseDateTime(nextShift['start_at']))} with ${_caregiverNameById(nextShift['caregiver'] as int?)}'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...shifts.take(3).map((shift) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _MiniShiftRow(
                            title: '${_formatDayAndTime(_parseDateTime(shift['start_at']))} - ${_formatTime(_parseDateTime(shift['end_at']))}',
                            subtitle: '${_caregiverNameById(shift['caregiver'] as int?)} • ${_shiftTypeLabel(shift['shift_type']?.toString() ?? 'visit')}',
                            color: _shiftTypeColor(shift['shift_type']?.toString() ?? 'visit'),
                          ),
                        )),
                    if (shifts.length > 3)
                      Text('+${shifts.length - 3} more scheduled', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildPatientAssignmentsTab(ColorScheme cs) {
    final selectedCaregiver = _selectedCaregiver;
    final patients = _filteredPatients;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Patient assignments', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('Select a caregiver, review their patient panel, then save secondary assignments.', style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _selectedCaregiverId == null ? null : () => _loadAssignments(_selectedCaregiverId!),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reload'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 116,
                child: _caregivers.isEmpty
                    ? const Center(child: Text('No caregivers available'))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemBuilder: (context, index) {
                          final caregiver = _caregivers[index];
                          final selected = caregiver['id'] == _selectedCaregiverId;
                          return _CaregiverPickerCard(
                            caregiver: caregiver,
                            selected: selected,
                            onTap: () => _selectCaregiver(caregiver['id'] as int),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemCount: _caregivers.length,
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (selectedCaregiver != null)
          _SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SelectedCaregiverBanner(
                  caregiver: selectedCaregiver,
                  caregiverName: _caregiverDisplayName(selectedCaregiver),
                  activePatientsCount: (selectedCaregiver['active_patients_count'] as num?)?.toInt() ?? 0,
                  isDirty: _isDirty,
                  pendingChangeCount: _pendingChangeCount,
                ),
                if (_isDirty) ...[
                  const SizedBox(height: 12),
                  _InlineBanner(
                    icon: Icons.pending_actions_rounded,
                    color: const Color(0xFFB45309),
                    background: const Color(0xFFFFF7ED),
                    message: '${_pendingAdd.length} to add and ${_pendingRemove.length} to remove. Save when the review is complete.',
                  ),
                ],
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 660;
                    final metrics = [
                      Expanded(
                        child: _AssignmentSummaryTile(label: 'Total selected', value: '${_currentAssigned.length}', color: const Color(0xFF0D9488)),
                      ),
                      Expanded(
                        child: _AssignmentSummaryTile(label: 'Primary', value: '$_primaryCount', color: const Color(0xFF6366F1)),
                      ),
                      Expanded(
                        child: _AssignmentSummaryTile(label: 'Pending', value: '$_pendingChangeCount', color: const Color(0xFFF59E0B)),
                      ),
                    ];
                    if (compact) {
                      return Column(
                        children: [
                          Row(children: [metrics[0], const SizedBox(width: 10), metrics[1]]),
                          const SizedBox(height: 10),
                          Row(children: [metrics[2]]),
                        ],
                      );
                    }
                    return Row(
                      children: [metrics[0], const SizedBox(width: 10), metrics[1], const SizedBox(width: 10), metrics[2]],
                    );
                  },
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 660;
                    final search = TextField(
                      controller: _patientSearchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'Search patients, MRN, diagnosis',
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    );
                    final reload = OutlinedButton.icon(
                      onPressed: _selectedCaregiverId == null ? null : () => _loadAssignments(_selectedCaregiverId!),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reload draft'),
                    );
                    if (compact) {
                      return Column(
                        children: [
                          search,
                          const SizedBox(height: 12),
                          SizedBox(width: double.infinity, child: reload),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: search),
                        const SizedBox(width: 12),
                        reload,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 8,
                  spacing: 8,
                  children: [
                    _ChoicePill(label: 'All', selected: _patientFilter == 'all', onTap: () => setState(() => _patientFilter = 'all')),
                    _ChoicePill(label: 'Assigned', selected: _patientFilter == 'assigned', onTap: () => setState(() => _patientFilter = 'assigned'), color: const Color(0xFF0D9488)),
                    _ChoicePill(label: 'Unassigned', selected: _patientFilter == 'unassigned', onTap: () => setState(() => _patientFilter = 'unassigned'), color: const Color(0xFF64748B)),
                    TextButton(onPressed: _selectAllVisible, child: const Text('Select visible')),
                    TextButton(onPressed: _clearVisible, child: const Text('Clear visible')),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (selectedCaregiver == null)
          _EmptyPanel(
            icon: Icons.account_tree_rounded,
            title: 'Select a caregiver to manage assignments',
            subtitle: 'The mobile screen syncs the same caregiver-to-patient assignment set used on the web page.',
          )
        else if (_loadingAssignments)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (patients.isEmpty)
          _EmptyPanel(
            icon: Icons.person_off_rounded,
            title: 'No patients match the current filter',
            subtitle: 'Try clearing the search or switch between assigned and unassigned.',
          )
        else
          ...patients.map((patient) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildPatientAssignmentCard(patient, cs),
              )),
      ],
    );
  }

  Widget _buildCaregiverSheetCard(Map<String, dynamic> caregiver, ColorScheme cs) {
    final caregiverId = caregiver['id'] as int;
    final shifts = _shiftsForCaregiverOnDate(caregiverId);
    final nowShift = _caregiverNowShift(caregiverId);
    final nextShift = _caregiverNextShift(caregiverId);
    final liveInActive = nowShift != null && nowShift['shift_type'] == 'live_in';
    final availability = _availabilityDescriptor(caregiver);

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _categoryColor(caregiver['category']?.toString()).withValues(alpha: 0.14),
                child: Text(
                  _initials(_caregiverDisplayName(caregiver)),
                  style: TextStyle(color: _categoryColor(caregiver['category']?.toString()), fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_caregiverDisplayName(caregiver), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      '${caregiver['category_label'] ?? _categoryLabel(caregiver['category']?.toString())}${(caregiver['license_number'] ?? '').toString().isNotEmpty ? ' • #${caregiver['license_number']}' : ''}',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _StatusBadge(label: availability.label, color: availability.color),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: availability.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(availability.icon, size: 18, color: availability.color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nowShift != null
                        ? 'Engaged with ${nowShift['patient_name']} until ${_formatTime(_parseDateTime(nowShift['end_at']))}${liveInActive ? ' · LIVE-IN' : ''}'
                        : nextShift != null
                            ? 'Next shift ${_formatRelative(_parseDateTime(nextShift['start_at']))} with ${nextShift['patient_name']}'
                            : 'No scheduled shifts on ${_formatLongDate(_sheetDate)}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${shifts.length} shift${shifts.length == 1 ? '' : 's'} on ${_formatLongDate(_sheetDate)}', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _selectCaregiver(caregiverId, jumpToAssignments: true),
                icon: const Icon(Icons.account_tree_rounded),
                label: const Text('Manage'),
              ),
            ],
          ),
          if (shifts.isEmpty)
            const _MiniNotice(message: 'No shifts booked for this caregiver on the selected day.')
          else
            ...shifts.map((shift) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _ShiftTimelineTile(shift: shift, accent: _shiftTypeColor(shift['shift_type']?.toString() ?? 'visit')),
                )),
        ],
      ),
    );
  }

  Widget _buildPatientAssignmentCard(Map<String, dynamic> patient, ColorScheme cs) {
    final patientId = patient['id'] as int;
    final selected = _currentAssigned.contains(patientId);
    final primary = _selectedCaregiverId != null && patient['assigned_caregiver'] == _selectedCaregiverId;
    final additional = selected && !primary;
    final accent = primary
        ? const Color(0xFF6366F1)
        : additional
            ? const Color(0xFF0D9488)
            : cs.outlineVariant;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: primary || additional ? accent.withValues(alpha: 0.07) : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: primary || additional ? accent.withValues(alpha: 0.42) : cs.outlineVariant.withValues(alpha: 0.22), width: primary || additional ? 1.4 : 1),
        boxShadow: [
          BoxShadow(
            color: (primary || additional ? accent : Colors.black).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: primary ? null : () => _togglePatient(patientId),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _riskColor(patient['risk_level']?.toString()).withValues(alpha: 0.12),
                  child: Text(_initials(_patientName(patient)), style: TextStyle(color: _riskColor(patient['risk_level']?.toString()), fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(_patientName(patient), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                          ),
                          if (primary)
                            const _StatusBadge(label: 'Primary', color: Color(0xFF6366F1))
                          else if (additional)
                            const _StatusBadge(label: 'Secondary', color: Color(0xFF0D9488)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${patient['medical_record_number'] ?? 'No MRN'}${(patient['primary_diagnosis'] ?? '').toString().isNotEmpty ? ' • ${patient['primary_diagnosis']}' : ''}',
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TinyChip(label: (patient['risk_level'] ?? 'low').toString().toUpperCase(), color: _riskColor(patient['risk_level']?.toString())),
                          if ((patient['assigned_caregiver_name'] ?? '').toString().isNotEmpty)
                            _TinyChip(label: 'Primary: ${patient['assigned_caregiver_name']}', color: const Color(0xFF6366F1)),
                          if ((patient['open_escalations'] ?? 0) is num && (patient['open_escalations'] as num) > 0)
                            _TinyChip(label: '${patient['open_escalations']} open escalations', color: const Color(0xFFEF4444)),
                        ],
                      ),
                      if (primary) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'This patient is already locked to the caregiver as the primary assignment.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                      ] else if (additional) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Included in the current secondary-assignment draft.',
                          style: TextStyle(fontSize: 12, color: accent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: (primary || additional ? accent : cs.surfaceContainerHighest).withValues(alpha: primary || additional ? 0.14 : 0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        primary
                            ? Icons.lock_rounded
                            : additional
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                        color: primary || additional ? accent : cs.onSurfaceVariant,
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Switch.adaptive(
                      value: selected,
                      onChanged: primary ? null : (_) => _togglePatient(patientId),
                      activeTrackColor: const Color(0xFF0D9488).withValues(alpha: 0.45),
                      activeThumbColor: const Color(0xFF0D9488),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _togglePatient(int patientId) {
    final patient = _patientById(patientId);
    if (patient == null) return;
    if (_selectedCaregiverId != null && patient['assigned_caregiver'] == _selectedCaregiverId) {
      return;
    }
    setState(() {
      if (_currentAssigned.contains(patientId)) {
        _currentAssigned.remove(patientId);
      } else {
        _currentAssigned.add(patientId);
      }
    });
  }

  void _selectAllVisible() {
    setState(() {
      for (final patient in _filteredPatients) {
        _currentAssigned.add(patient['id'] as int);
      }
    });
  }

  void _clearVisible() {
    setState(() {
      for (final patient in _filteredPatients) {
        if (_selectedCaregiverId != null && patient['assigned_caregiver'] == _selectedCaregiverId) continue;
        _currentAssigned.remove(patient['id'] as int);
      }
    });
  }

  List<Map<String, dynamic>> get _filteredSheetCaregivers {
    final query = _caregiverSearchController.text.trim().toLowerCase();
    return _caregivers.where((caregiver) {
      if (query.isNotEmpty) {
        final blob = '${_caregiverDisplayName(caregiver)} ${caregiver['category_label'] ?? ''} ${caregiver['license_number'] ?? ''}'.toLowerCase();
        if (!blob.contains(query)) return false;
      }
      final caregiverId = caregiver['id'] as int;
      switch (_sheetFilter) {
        case 'available':
          return _caregiverNowShift(caregiverId) == null;
        case 'engaged':
          return _caregiverNowShift(caregiverId) != null;
        case 'livein':
          return _shiftsForCaregiverOnDate(caregiverId).any((shift) => shift['shift_type'] == 'live_in');
        case 'off':
          return _shiftsForCaregiverOnDate(caregiverId).isEmpty;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredPatients {
    final query = _patientSearchController.text.trim().toLowerCase();
    return _patients.where((patient) {
      final id = patient['id'] as int;
      if (_patientFilter == 'assigned' && !_currentAssigned.contains(id)) return false;
      if (_patientFilter == 'unassigned' && _currentAssigned.contains(id)) return false;
      if (query.isEmpty) return true;
      final blob = '${_patientName(patient)} ${patient['medical_record_number'] ?? ''} ${patient['primary_diagnosis'] ?? ''}'.toLowerCase();
      return blob.contains(query);
    }).toList();
  }

  Map<String, dynamic>? get _selectedCaregiver {
    if (_selectedCaregiverId == null) return null;
    for (final caregiver in _caregivers) {
      if (caregiver['id'] == _selectedCaregiverId) return caregiver;
    }
    return null;
  }

  List<Map<String, dynamic>> get _upcomingShifts {
    final start = DateTime(_sheetDate.year, _sheetDate.month, _sheetDate.day);
    final end = start.add(const Duration(days: 14));
    final shifts = _shifts.where((shift) {
      final dt = _parseDateTime(shift['start_at']);
      return dt != null && !dt.isBefore(start) && dt.isBefore(end);
    }).toList();
    shifts.sort((a, b) => _parseDateTime(a['start_at'])!.compareTo(_parseDateTime(b['start_at'])!));
    return shifts;
  }

  int get _availableNowCount => _caregivers.where((caregiver) => _caregiverNowShift(caregiver['id'] as int) == null).length;

  int get _engagedNowCount => _caregivers.where((caregiver) => _caregiverNowShift(caregiver['id'] as int) != null).length;

  int get _todayShiftsCount => _shifts.where((shift) {
        final start = _parseDateTime(shift['start_at']);
        return start != null && _isSameDay(start, _sheetDate);
      }).length;

  int get _primaryCount => _patients.where((patient) => patient['assigned_caregiver'] == _selectedCaregiverId).length;

  List<int> get _pendingAdd => _currentAssigned.where((id) => !_initialAssigned.contains(id)).toList();

  List<int> get _pendingRemove => _initialAssigned.where((id) => !_currentAssigned.contains(id)).toList();

  int get _pendingChangeCount => _pendingAdd.length + _pendingRemove.length;

  bool get _isDirty {
    if (_currentAssigned.length != _initialAssigned.length) return true;
    for (final id in _currentAssigned) {
      if (!_initialAssigned.contains(id)) return true;
    }
    return false;
  }

  List<Map<String, dynamic>> _shiftsForCaregiverOnDate(int caregiverId) {
    final shifts = _shifts.where((shift) {
      final start = _parseDateTime(shift['start_at']);
      return shift['caregiver'] == caregiverId && start != null && _isSameDay(start, _sheetDate);
    }).toList();
    shifts.sort((a, b) => _parseDateTime(a['start_at'])!.compareTo(_parseDateTime(b['start_at'])!));
    return shifts;
  }

  Map<String, dynamic>? _caregiverNowShift(int caregiverId) {
    final now = DateTime.now();
    for (final shift in _shifts) {
      if (shift['caregiver'] != caregiverId) continue;
      final start = _parseDateTime(shift['start_at']);
      final end = _parseDateTime(shift['end_at']);
      final status = shift['status']?.toString();
      if (start == null || end == null) continue;
      if (status == 'cancelled' || status == 'completed' || status == 'missed') continue;
      if (!now.isBefore(start) && now.isBefore(end)) return shift;
    }
    return null;
  }

  Map<String, dynamic>? _caregiverNextShift(int caregiverId) {
    final now = DateTime.now();
    final upcoming = _shifts.where((shift) {
      if (shift['caregiver'] != caregiverId) return false;
      final start = _parseDateTime(shift['start_at']);
      return start != null && start.isAfter(now);
    }).toList();
    if (upcoming.isEmpty) return null;
    upcoming.sort((a, b) => _parseDateTime(a['start_at'])!.compareTo(_parseDateTime(b['start_at'])!));
    return upcoming.first;
  }

  List<Map<String, dynamic>> _patientUpcomingShifts(int patientId) {
    final now = DateTime.now();
    final shifts = _shifts.where((shift) {
      final start = _parseDateTime(shift['start_at']);
      return shift['patient'] == patientId && start != null && !start.isBefore(now);
    }).toList();
    shifts.sort((a, b) => _parseDateTime(a['start_at'])!.compareTo(_parseDateTime(b['start_at'])!));
    return shifts.take(6).toList();
  }

  Map<String, List<Map<String, dynamic>>> _groupShiftsByDate(List<Map<String, dynamic>> shifts) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final shift in shifts) {
      final start = _parseDateTime(shift['start_at']);
      if (start == null) continue;
      final key = _formatLongDate(start);
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(shift);
    }
    return grouped;
  }

  _AvailabilityDescriptor _availabilityDescriptor(Map<String, dynamic> caregiver) {
    final caregiverId = caregiver['id'] as int;
    final nowShift = _caregiverNowShift(caregiverId);
    if (nowShift != null) {
      return const _AvailabilityDescriptor(label: 'Engaged', color: Color(0xFFF59E0B), icon: Icons.pending_actions_rounded);
    }
    if (_shiftsForCaregiverOnDate(caregiverId).isEmpty) {
      return const _AvailabilityDescriptor(label: 'Off shift', color: Color(0xFF64748B), icon: Icons.free_breakfast_rounded);
    }
    return const _AvailabilityDescriptor(label: 'Available', color: Color(0xFF10B981), icon: Icons.check_circle_rounded);
  }

  Map<String, dynamic>? _patientById(int id) {
    for (final patient in _patients) {
      if (patient['id'] == id) return patient;
    }
    return null;
  }
}

class _AssignmentsHero extends StatelessWidget {
  const _AssignmentsHero({
    required this.caregiverCount,
    required this.availableNowCount,
    required this.engagedNowCount,
    required this.todayShiftsCount,
  });

  final int caregiverCount;
  final int availableNowCount;
  final int engagedNowCount;
  final int todayShiftsCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF312E81), Color(0xFF4F46E5), Color(0xFF0EA5E9)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: const Icon(Icons.account_tree_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOMECARE · CARE OPERATIONS',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assignment sheets',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Roster shifts, review availability, and sync patient assignments with the live homecare schedule.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13.5, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroChip(label: '$caregiverCount caregivers', icon: Icons.group_rounded),
              _HeroChip(label: '$availableNowCount available', icon: Icons.check_circle_rounded),
              _HeroChip(label: '$engagedNowCount engaged', icon: Icons.pending_actions_rounded),
              _HeroChip(label: '$todayShiftsCount shifts today', icon: Icons.calendar_month_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

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
          Icon(icon, size: 16, color: const Color(0xFF312E81)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFF312E81), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData({required this.label, required this.value, required this.color, required this.icon});

  final String label;
  final String value;
  final Color color;
  final IconData icon;
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.metrics});

  final List<_MetricData> metrics;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final metric = metrics[index];
          return Container(
            width: 156,
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(minHeight: 108),
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: metric.color.withValues(alpha: 0.16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(metric.icon, color: metric.color, size: 18),
                const Spacer(),
                Text(metric.value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: metric.color)),
                Text(metric.label, style: TextStyle(color: metric.color.withValues(alpha: 0.86), fontWeight: FontWeight.w600)),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: metrics.length,
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({required this.label, required this.selected, required this.onTap, this.color});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? const Color(0xFF312E81);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? resolved.withValues(alpha: 0.14) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? resolved.withValues(alpha: 0.28) : Colors.transparent),
          ),
          child: Text(label, style: TextStyle(color: selected ? resolved : Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _InfoLozenge extends StatelessWidget {
  const _InfoLozenge({required this.icon, required this.label, required this.value, required this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 156),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.78), fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedCaregiverBanner extends StatelessWidget {
  const _SelectedCaregiverBanner({
    required this.caregiver,
    required this.caregiverName,
    required this.activePatientsCount,
    required this.isDirty,
    required this.pendingChangeCount,
  });

  final Map<String, dynamic> caregiver;
  final String caregiverName;
  final int activePatientsCount;
  final bool isDirty;
  final int pendingChangeCount;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(caregiver['category']?.toString());
    final cs = Theme.of(context).colorScheme;
    final specialties = (caregiver['specialties'] as List?)?.whereType<String>().where((item) => item.trim().isNotEmpty).take(2).toList() ?? const <String>[];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.14), color.withValues(alpha: 0.04)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.14),
                child: Text(_initials(caregiverName), style: TextStyle(color: color, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(caregiverName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      caregiver['category_label']?.toString() ?? _categoryLabel(caregiver['category']?.toString()),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              _StatusBadge(
                label: isDirty ? '$pendingChangeCount pending' : 'Synced',
                color: isDirty ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TinyChip(label: '$activePatientsCount active patients', color: color),
              if ((caregiver['employment_status'] ?? '').toString().isNotEmpty)
                _TinyChip(label: '${caregiver['employment_status']}'.toString().replaceAll('_', ' '), color: const Color(0xFF6366F1)),
              if (specialties.isNotEmpty) ...specialties.map((item) => _TinyChip(label: item, color: const Color(0xFF0EA5E9))),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssignmentActionBar extends StatelessWidget {
  const _AssignmentActionBar({
    required this.caregiverName,
    required this.pendingChanges,
    required this.saving,
    required this.onDiscard,
    required this.onSave,
  });

  final String caregiverName;
  final int pendingChanges;
  final bool saving;
  final VoidCallback? onDiscard;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    saving ? 'Saving assignment changes...' : '$pendingChanges change${pendingChanges == 1 ? '' : 's'} ready to save',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(caregiverName, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: onDiscard,
              child: const Text('Discard'),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onSave,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(saving ? 'Saving...' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11.5)),
    );
  }
}

class _ShiftTimelineTile extends StatelessWidget {
  const _ShiftTimelineTile({required this.shift, required this.accent});

  final Map<String, dynamic> shift;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final start = _parseDateTime(shift['start_at']);
    final end = _parseDateTime(shift['end_at']);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${shift['patient_name'] ?? 'Patient'} · ${shift['caregiver_name'] ?? 'Caregiver'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDayAndTime(start)} - ${_formatTime(end)} • ${_shiftTypeLabel(shift['shift_type']?.toString() ?? 'visit')}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5),
                ),
              ],
            ),
          ),
          _StatusBadge(label: (shift['status'] ?? 'scheduled').toString().toUpperCase(), color: _statusColor(shift['status']?.toString())),
        ],
      ),
    );
  }
}

class _MiniShiftRow extends StatelessWidget {
  const _MiniShiftRow({required this.title, required this.subtitle, required this.color});

  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.timelapse_rounded, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaregiverPickerCard extends StatelessWidget {
  const _CaregiverPickerCard({required this.caregiver, required this.selected, required this.onTap});

  final Map<String, dynamic> caregiver;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(caregiver['category']?.toString());
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 170,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? color : Colors.transparent, width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.16),
                child: Text(_initials(_caregiverDisplayName(caregiver)), style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Row(
                children: [
                  _TinyChip(label: '${(caregiver['active_patients_count'] as num?)?.toInt() ?? 0} active', color: color),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.check_circle_rounded, color: color, size: 18),
                  ],
                ],
              ),
              const Spacer(),
              Text(_caregiverDisplayName(caregiver), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(caregiver['category_label']?.toString() ?? _categoryLabel(caregiver['category']?.toString()), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignmentSummaryTile extends StatelessWidget {
  const _AssignmentSummaryTile({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: const BoxConstraints(minHeight: 96),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 22)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TinyChip extends StatelessWidget {
  const _TinyChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11.5)),
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({super.key, required this.icon, required this.color, required this.background, required this.message});

  final IconData icon;
  final Color color;
  final Color background;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          CircleAvatar(radius: 28, backgroundColor: cs.surfaceContainerHighest, child: Icon(icon, color: cs.primary)),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant, height: 1.45), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _MiniNotice extends StatelessWidget {
  const _MiniNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

class _AvailabilityDescriptor {
  const _AvailabilityDescriptor({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;
}

List<Map<String, dynamic>> _listFromResponse(dynamic data) {
  final raw = data is List ? data : (data is Map<String, dynamic> ? data['results'] : null);
  if (raw is! List) return const [];
  return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

bool _isSameDay(DateTime left, DateTime right) =>
    left.year == right.year && left.month == right.month && left.day == right.day;

String _formatLongDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _formatDayAndTime(DateTime? date) {
  if (date == null) return 'Unknown time';
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[date.weekday - 1]} ${_formatTime(date)}';
}

String _formatTime(DateTime? date) {
  if (date == null) return '--:--';
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String _formatRelative(DateTime? date) {
  if (date == null) return 'soon';
  final now = DateTime.now();
  final diff = date.difference(now);
  if (diff.inMinutes.abs() < 60) {
    final mins = math.max(1, diff.inMinutes.abs());
    return diff.isNegative ? '$mins min ago' : 'in $mins min';
  }
  if (diff.inHours.abs() < 24) {
    final hours = diff.inHours.abs();
    return diff.isNegative ? '$hours hr ago' : 'in $hours hr';
  }
  final days = diff.inDays.abs();
  return diff.isNegative ? '$days d ago' : 'in $days d';
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
}

String _patientName(Map<String, dynamic> patient) {
  final user = patient['user'] as Map<String, dynamic>? ?? const {};
  final fullName = (user['full_name'] ?? '').toString().trim();
  if (fullName.isNotEmpty) return fullName;
  final joined = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
  if (joined.isNotEmpty) return joined;
  return user['email']?.toString() ?? 'Patient #${patient['id']}';
}

String _caregiverDisplayName(Map<String, dynamic> caregiver) {
  final user = caregiver['user'] as Map<String, dynamic>? ?? const {};
  final fullName = (user['full_name'] ?? '').toString().trim();
  if (fullName.isNotEmpty) return fullName;
  final joined = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
  if (joined.isNotEmpty) return joined;
  return user['email']?.toString() ?? 'Caregiver #${caregiver['id']}';
}

String _caregiverNameByIdFrom(List<Map<String, dynamic>> caregivers, int? id) {
  if (id == null) return 'Caregiver';
  for (final caregiver in caregivers) {
    if (caregiver['id'] == id) return _caregiverDisplayName(caregiver);
  }
  return 'Caregiver';
}

extension on _HomecareAssignmentsScreenState {
  String _caregiverNameById(int? id) => _caregiverNameByIdFrom(_caregivers, id);
}

Color _categoryColor(String? category) {
  switch (category) {
    case 'nurse':
      return const Color(0xFF0D9488);
    case 'hca':
      return const Color(0xFF6366F1);
    default:
      return const Color(0xFF475569);
  }
}

String _categoryLabel(String? category) {
  switch (category) {
    case 'nurse':
      return 'Nurse';
    case 'hca':
      return 'HCA';
    default:
      return 'Caregiver';
  }
}

Color _shiftTypeColor(String shiftType) {
  switch (shiftType) {
    case 'live_in':
      return const Color(0xFF8B5CF6);
    case 'on_call':
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFF0EA5E9);
  }
}

String _shiftTypeLabel(String shiftType) {
  switch (shiftType) {
    case 'live_in':
      return 'Live-in';
    case 'on_call':
      return 'On-call';
    default:
      return 'Visit';
  }
}

Color _statusColor(String? status) {
  switch (status) {
    case 'checked_in':
      return const Color(0xFF10B981);
    case 'completed':
      return const Color(0xFF0D9488);
    case 'missed':
      return const Color(0xFFEF4444);
    case 'cancelled':
      return const Color(0xFF64748B);
    default:
      return const Color(0xFFF59E0B);
  }
}

Color _riskColor(String? riskLevel) {
  switch (riskLevel) {
    case 'critical':
      return const Color(0xFFDC2626);
    case 'high':
      return const Color(0xFFF97316);
    case 'medium':
      return const Color(0xFFD97706);
    default:
      return const Color(0xFF16A34A);
  }
}

String? _extractError(dynamic data) {
  if (data is Map && data['detail'] != null) return data['detail'].toString();
  if (data is String && data.trim().isNotEmpty) return data;
  return null;
}