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
        padding: const EdgeInsets.only(bottom: 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.05,
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
    final initials = doctor.name.trim().isNotEmpty
        ? doctor.name.trim().split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase()
        : 'D';
    final hasPhoto = doctor.profilePictureUrl?.isNotEmpty == true;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Left 50% — photo panel ────────────────────────
            Flexible(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  image: hasPhoto
                      ? DecorationImage(
                          image: NetworkImage(doctor.profilePictureUrl!),
                          fit: BoxFit.cover,
                          onError: (_, __) {},
                        )
                      : null,
                ),
                child: !hasPhoto
                    ? Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            // ── Right 50% — details ───────────────────────────
            Flexible(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + verified
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Dr. ${doctor.name}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (doctor.isVerified)
                          Icon(Icons.verified,
                              color: AppColors.primary, size: 15),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Specialization
                    Text(
                      doctor.specialization,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Experience
                    if (doctor.yearsOfExperience > 0)
                      Row(
                        children: [
                          Icon(Icons.work_outline,
                              size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text(
                            '${doctor.yearsOfExperience} yrs exp',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    // Languages
                    if (doctor.languages.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.translate,
                              size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              doctor.languages.join(', '),
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Available days
                    if (doctor.availableDays.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              doctor.availableDays
                                  .map((d) => d.length >= 3
                                      ? d.substring(0, 3)
                                      : d)
                                  .join(' · '),
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Spacer(),
                    // Fee
                    if (doctor.consultationFee > 0)
                      Text(
                        'KES ${doctor.consultationFee.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontSize: 13,
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onTap,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Profile',
                                style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: FilledButton(
                            onPressed: onChat,
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 30),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Consult',
                                style: TextStyle(fontSize: 11)),
                          ),
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
    );
  }
}
