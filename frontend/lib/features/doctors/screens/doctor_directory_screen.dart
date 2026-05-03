import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/search_field.dart';
import '../models/doctor_model.dart';
import '../repository/doctor_repository.dart';

class DoctorDirectoryScreen extends ConsumerStatefulWidget {
  const DoctorDirectoryScreen({super.key});

  @override
  ConsumerState<DoctorDirectoryScreen> createState() =>
      _DoctorDirectoryScreenState();
}

class _DoctorDirectoryScreenState
    extends ConsumerState<DoctorDirectoryScreen> {
  final _repo = DoctorRepository();
  PaginatedResponse<DoctorProfile>? _data;
  bool _loading = true;
  String? _error;
  int _page = 1;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repo.getDirectory(
        page: _page,
        search: _search.isEmpty ? null : _search,
      );
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find a Doctor',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Browse available doctors and start a consultation',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          SearchField(
            hintText: 'Search by name or specialization...',
            onChanged: (value) {
              _search = value;
              _page = 1;
              _loadData();
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _error != null
                    ? app_error.AppErrorWidget(
                        message: _error!, onRetry: _loadData)
                    : _data == null || _data!.results.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.person_search_outlined,
                            title: 'No doctors found',
                            subtitle:
                                'Try a different search or check back later',
                          )
                        : _buildDoctorGrid(),
          ),
          if (_data != null && _data!.count > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_data!.count} doctors found',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  Row(children: [
                    TextButton(
                      onPressed: _data!.previous != null
                          ? () {
                              _page--;
                              _loadData();
                            }
                          : null,
                      child: const Text('Previous'),
                    ),
                    const SizedBox(width: 8),
                    Text('Page $_page',
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _data!.next != null
                          ? () {
                              _page++;
                              _loadData();
                            }
                          : null,
                      child: const Text('Next'),
                    ),
                  ]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDoctorGrid() {
    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = constraints.maxWidth > 900
          ? 3
          : constraints.maxWidth > 600
              ? 2
              : 1;
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.35,
        ),
        itemCount: _data!.results.length,
        itemBuilder: (context, index) {
          final doc = _data!.results[index];
          return _DoctorCard(
            doctor: doc,
            onTap: () => context.push('/doctors/${doc.id}'),
            onChat: () => context.push('/doctors/${doc.id}/chat'),
          );
        },
      );
    });
  }
}

class _DoctorCard extends StatelessWidget {
  final DoctorProfile doctor;
  final VoidCallback onTap;
  final VoidCallback onChat;

  const _DoctorCard({
    required this.doctor,
    required this.onTap,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      doctor.name.isNotEmpty
                          ? doctor.name[0].toUpperCase()
                          : 'D',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dr. ${doctor.name}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          doctor.specialization,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (doctor.isVerified)
                    Tooltip(
                      message: 'Verified',
                      child: Icon(Icons.verified,
                          color: AppColors.primary, size: 20),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (doctor.qualification.isNotEmpty ||
                  doctor.yearsOfExperience > 0)
                Row(
                  children: [
                    if (doctor.qualification.isNotEmpty) ...[
                      Icon(Icons.school_outlined,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(doctor.qualification,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 12),
                    ],
                    if (doctor.yearsOfExperience > 0) ...[
                      Icon(Icons.work_outline,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('${doctor.yearsOfExperience} yrs',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: doctor.practiceType == 'independent'
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      doctor.practiceType == 'independent'
                          ? 'Independent'
                          : doctor.hospitalName ?? 'Hospital',
                      style: TextStyle(
                        fontSize: 11,
                        color: doctor.practiceType == 'independent'
                            ? Colors.blue
                            : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (doctor.consultationFee > 0)
                    Text(
                      'KES ${doctor.consultationFee.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.info_outline, size: 16),
                      label: const Text('Profile'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onChat,
                      icon: const Icon(Icons.chat_outlined, size: 16),
                      label: const Text('Consult'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
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
