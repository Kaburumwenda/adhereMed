import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/empty_state_widget.dart';
import '../models/patient_model.dart';
import '../repository/patient_repository.dart';

class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  final _repo = PatientRepository();
  final _searchCtrl = TextEditingController();
  PaginatedResponse<Patient>? _data;
  bool _loading = true;
  String? _error;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _repo.getPatients(
        page: _page,
        search: _searchCtrl.text.isEmpty ? null : _searchCtrl.text,
      );
      setState(() { _data = result; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _onSearch(String _) {
    _page = 1;
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.people_alt_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patients',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    if (_data != null)
                      Text('${_data!.count} registered patients',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push('/patients/new'),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Register Patient'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Search ──
          TextField(
            controller: _searchCtrl,
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: 'Search by name or patient number...',
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onSearch('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
          const SizedBox(height: 16),

          // ── Content ──
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _error != null
                    ? app_error.AppErrorWidget(message: _error!, onRetry: _loadData)
                    : _data == null || _data!.results.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.people_outline,
                            title: 'No patients found',
                            subtitle: 'Register a new patient to get started.',
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: ListView.separated(
                                  itemCount: _data!.results.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    return _PatientCard(
                                      patient: _data!.results[index],
                                      onView: () => context.push('/patients/${_data!.results[index].id}'),
                                      onEdit: () => context.push('/patients/${_data!.results[index].id}/edit'),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              _Pagination(
                                page: _page,
                                total: _data!.count,
                                hasPrev: _data!.previous != null,
                                hasNext: _data!.next != null,
                                onPrev: () { _page--; _loadData(); },
                                onNext: () { _page++; _loadData(); },
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Patient Card ──────────────────────────────────────────────────────────────

class _PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback onView;
  final VoidCallback onEdit;

  const _PatientCard({required this.patient, required this.onView, required this.onEdit});

  Color get _avatarColor {
    final colors = [
      const Color(0xFF0D9488), const Color(0xFF6366F1), const Color(0xFFF59E0B),
      const Color(0xFFEF4444), const Color(0xFF8B5CF6), const Color(0xFF06B6D4),
    ];
    return colors[(patient.fullName.codeUnitAt(0)) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final initials = [
      patient.firstName.isNotEmpty ? patient.firstName[0] : '',
      patient.lastName.isNotEmpty ? patient.lastName[0] : '',
    ].join().toUpperCase();

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundColor: _avatarColor.withValues(alpha: 0.15),
                child: Text(initials,
                    style: TextStyle(
                        color: _avatarColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(patient.fullName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                        ),
                        if (patient.bloodGroup != null && patient.bloodGroup!.isNotEmpty)
                          _Chip(patient.bloodGroup!, color: AppColors.error),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.badge_outlined, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(patient.idNumber ?? 'No ID', // patient_number not in model - use idNumber
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(width: 12),
                        if (patient.email != null && patient.email!.isNotEmpty) ...[
                          Icon(Icons.email_outlined, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(patient.email!,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (patient.phone != null && patient.phone!.isNotEmpty) ...[
                          Icon(Icons.phone_outlined, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(patient.phone!,
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          const SizedBox(width: 12),
                        ],
                        if (patient.gender != null && patient.gender!.isNotEmpty)
                          _Chip(
                            patient.gender![0].toUpperCase() + patient.gender!.substring(1),
                            color: patient.gender == 'male'
                                ? const Color(0xFF3B82F6)
                                : patient.gender == 'female'
                                    ? const Color(0xFFEC4899)
                                    : AppColors.textSecondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Column(
                children: [
                  IconButton(
                    onPressed: onView,
                    icon: Icon(Icons.visibility_rounded, color: AppColors.primary, size: 20),
                    tooltip: 'View',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    ),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_rounded, color: AppColors.secondary, size: 20),
                    tooltip: 'Edit',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.secondary.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _Pagination extends StatelessWidget {
  final int page;
  final int total;
  final bool hasPrev;
  final bool hasNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _Pagination({
    required this.page, required this.total,
    required this.hasPrev, required this.hasNext,
    required this.onPrev, required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('$total total records',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Row(children: [
          IconButton(
            onPressed: hasPrev ? onPrev : null,
            icon: const Icon(Icons.chevron_left_rounded),
            style: IconButton.styleFrom(
              backgroundColor: hasPrev ? AppColors.primary.withValues(alpha: 0.1) : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('Page $page',
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
          IconButton(
            onPressed: hasNext ? onNext : null,
            icon: const Icon(Icons.chevron_right_rounded),
            style: IconButton.styleFrom(
              backgroundColor: hasNext ? AppColors.primary.withValues(alpha: 0.1) : null,
            ),
          ),
        ]),
      ],
    );
  }
}
