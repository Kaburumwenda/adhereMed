import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../models/doctor_model.dart';
import '../repository/doctor_repository.dart';

class DoctorDetailScreen extends ConsumerStatefulWidget {
  final String doctorId;
  const DoctorDetailScreen({super.key, required this.doctorId});

  @override
  ConsumerState<DoctorDetailScreen> createState() =>
      _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends ConsumerState<DoctorDetailScreen> {
  final _repo = DoctorRepository();
  DoctorProfile? _doctor;
  bool _loading = true;
  String? _error;

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
      final d = await _repo.getDoctor(int.parse(widget.doctorId));
      setState(() {
        _doctor = d;
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
    if (_loading) return const LoadingWidget();
    if (_error != null) {
      return app_error.AppErrorWidget(message: _error!, onRetry: _loadData);
    }
    final d = _doctor!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Dr. ${d.name}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push('/doctors/${d.id}/chat'),
                icon: const Icon(Icons.chat, size: 18),
                label: const Text('Start Consultation'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Profile card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        child: Text(
                          d.name.isNotEmpty ? d.name[0].toUpperCase() : 'D',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Dr. ${d.name}',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                if (d.isVerified) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.verified,
                                      color: AppColors.primary, size: 20),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(d.specialization,
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 32,
                    runSpacing: 12,
                    children: [
                      _infoChip(Icons.business_outlined,
                          d.practiceType == 'independent'
                              ? 'Independent Practice'
                              : d.hospitalName ?? 'Hospital-Affiliated'),
                      if (d.qualification.isNotEmpty)
                        _infoChip(Icons.school_outlined, d.qualification),
                      if (d.yearsOfExperience > 0)
                        _infoChip(Icons.work_outline,
                            '${d.yearsOfExperience} years experience'),
                      if (d.consultationFee > 0)
                        _infoChip(Icons.attach_money,
                            'KES ${d.consultationFee.toStringAsFixed(0)}'),
                      if (d.email.isNotEmpty)
                        _infoChip(Icons.email_outlined, d.email),
                      if (d.phone.isNotEmpty)
                        _infoChip(Icons.phone_outlined, d.phone),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (d.bio.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('About',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(d.bio),
                  ],
                ),
              ),
            ),
          ],

          if (d.languages.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Languages',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: d.languages
                          .map((l) => Chip(label: Text(l)))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (d.availableDays.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Availability',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: d.availableDays
                          .map((day) => Chip(label: Text(day)))
                          .toList(),
                    ),
                    if (d.availableHours.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${d.availableHours['start'] ?? ''} - ${d.availableHours['end'] ?? ''}',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}
