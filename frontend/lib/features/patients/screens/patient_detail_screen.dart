import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/confirm_dialog.dart';
import '../models/patient_model.dart';
import '../repository/patient_repository.dart';

class PatientDetailScreen extends ConsumerStatefulWidget {
  final String patientId;
  const PatientDetailScreen({super.key, required this.patientId});

  @override
  ConsumerState<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen> {
  final _repo = PatientRepository();
  Patient? _patient;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _repo.getPatient(int.parse(widget.patientId));
      setState(() { _patient = result; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _deletePatient() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete Patient',
      content: 'Are you sure you want to delete this patient record? This action cannot be undone.',
    );
    if (!confirmed || !mounted) return;
    try {
      await _repo.deletePatient(int.parse(widget.patientId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Patient deleted successfully')),
        );
        context.go('/patients');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  static const _palette = [
    Color(0xFF0D9488), Color(0xFF6366F1), Color(0xFFF59E0B),
    Color(0xFFEF4444), Color(0xFF8B5CF6), Color(0xFF06B6D4),
    Color(0xFF10B981), Color(0xFFF97316),
  ];

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();
    if (_error != null) return app_error.AppErrorWidget(message: _error!, onRetry: _loadData);
    final p = _patient!;

    final avatarColor = _palette[p.fullName.codeUnitAt(0) % _palette.length];
    final initials = '${p.firstName.isNotEmpty ? p.firstName[0] : ''}${p.lastName.isNotEmpty ? p.lastName[0] : ''}'.toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Back + actions bar ──
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
              ),
              const SizedBox(width: 4),
              Text('Patient Profile',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => context.push('/patients/${widget.patientId}/edit'),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _deletePatient,
                icon: Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                label: Text('Delete', style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Hero header card ──
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [avatarColor, avatarColor.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  child: Text(initials,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.fullName,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (p.gender != null && p.gender!.isNotEmpty)
                            _HeroBadge(
                              p.gender![0].toUpperCase() + p.gender!.substring(1),
                              Icons.person_rounded,
                            ),
                          if (p.bloodGroup != null && p.bloodGroup!.isNotEmpty)
                            _HeroBadge(p.bloodGroup!, Icons.water_drop_rounded),
                          if (p.dateOfBirth != null && p.dateOfBirth!.isNotEmpty)
                            _HeroBadge(p.dateOfBirth!, Icons.cake_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Quick stats row ──
          Row(
            children: [
              _StatCard(Icons.phone_rounded, 'Phone', p.phone ?? 'Not set', AppColors.primary),
              const SizedBox(width: 12),
              _StatCard(Icons.email_rounded, 'Email', p.email ?? 'Not set', AppColors.secondary),
              const SizedBox(width: 12),
              _StatCard(Icons.badge_rounded, 'National ID', p.idNumber ?? 'Not set', const Color(0xFF8B5CF6)),
            ],
          ),
          const SizedBox(height: 20),

          // ── Info cards grid ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 650;
              final cards = [
                _InfoCard(
                  title: 'Personal Information',
                  icon: Icons.account_circle_rounded,
                  color: AppColors.primary,
                  rows: [
                    _InfoRow(Icons.person_rounded, 'Full Name', p.fullName),
                    _InfoRow(Icons.wc_rounded, 'Gender',
                        p.gender != null && p.gender!.isNotEmpty
                            ? p.gender![0].toUpperCase() + p.gender!.substring(1)
                            : '—'),
                    _InfoRow(Icons.cake_rounded, 'Date of Birth', p.dateOfBirth ?? '—'),
                    _InfoRow(Icons.water_drop_rounded, 'Blood Group', p.bloodGroup ?? '—'),
                    _InfoRow(Icons.badge_rounded, 'National ID', p.idNumber ?? '—'),
                  ],
                ),
                _InfoCard(
                  title: 'Contact Information',
                  icon: Icons.contact_phone_rounded,
                  color: AppColors.secondary,
                  rows: [
                    _InfoRow(Icons.email_rounded, 'Email', p.email ?? '—'),
                    _InfoRow(Icons.phone_rounded, 'Phone', p.phone ?? '—'),
                    _InfoRow(Icons.location_on_rounded, 'Address', p.address ?? '—'),
                    _InfoRow(Icons.emergency_rounded, 'Emergency Contact', p.emergencyContactName ?? '—'),
                    _InfoRow(Icons.phone_forwarded_rounded, 'Emergency Phone', p.emergencyContactPhone ?? '—'),
                  ],
                ),
                _InfoCard(
                  title: 'Medical Information',
                  icon: Icons.medical_information_rounded,
                  color: const Color(0xFFEF4444),
                  rows: [
                    _InfoRow(Icons.warning_amber_rounded, 'Allergies',
                        (p.allergies != null && p.allergies!.isNotEmpty) ? p.allergies! : 'None reported'),
                    _InfoRow(Icons.monitor_heart_rounded, 'Chronic Conditions',
                        (p.chronicConditions != null && p.chronicConditions!.isNotEmpty) ? p.chronicConditions! : 'None reported'),
                  ],
                ),
                _InfoCard(
                  title: 'Insurance Information',
                  icon: Icons.health_and_safety_rounded,
                  color: const Color(0xFF10B981),
                  rows: [
                    _InfoRow(Icons.business_rounded, 'Provider', p.insuranceProvider ?? '—'),
                    _InfoRow(Icons.confirmation_number_rounded, 'Policy Number', p.insurancePolicyNumber ?? '—'),
                  ],
                ),
              ];

              if (isWide) {
                return Column(children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 16),
                    Expanded(child: cards[1]),
                  ]),
                  const SizedBox(height: 16),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: cards[2]),
                    const SizedBox(width: 16),
                    Expanded(child: cards[3]),
                  ]),
                ]);
              }
              return Column(
                children: cards.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 16), child: c)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  const _HeroBadge(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_InfoRow> rows;
  const _InfoCard({required this.title, required this.icon, required this.color, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14, color: color)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
