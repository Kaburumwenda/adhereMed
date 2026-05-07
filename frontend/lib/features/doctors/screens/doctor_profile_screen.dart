import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../models/doctor_model.dart';
import '../repository/doctor_repository.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final myDoctorProfileProvider =
    FutureProvider.autoDispose<DoctorProfile>((ref) {
  return DoctorRepository().getMyProfile();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class DoctorProfileScreen extends ConsumerStatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  ConsumerState<DoctorProfileScreen> createState() =>
      _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends ConsumerState<DoctorProfileScreen> {
  bool _editing = false;
  bool _saving = false;
  bool _uploadingPicture = false;
  bool _uploadingSignature = false;

  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _specializationCtrl;
  late final TextEditingController _licenseCtrl;
  late final TextEditingController _qualificationCtrl;
  late final TextEditingController _yearsCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _feeCtrl;
  bool _isAcceptingPatients = true;

  static const _dayOptions = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const _languageOptions = [
    'English',
    'Swahili',
    'Arabic',
    'French',
    'Somali',
    'Kikuyu',
    'Luo',
  ];

  List<String> _selectedDays = [];
  List<String> _selectedLanguages = [];

  Future<void> _pickAndUploadPicture() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _uploadingPicture = true);
    try {
      await DoctorRepository().uploadProfilePicture(
        bytes: file.bytes!,
        filename: file.name,
      );
      ref.invalidate(myDoctorProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPicture = false);
    }
  }

  Future<void> _openSignaturePad() async {
    final bytes = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SignaturePadDialog(),
    );
    if (bytes == null || bytes.isEmpty) return;

    setState(() => _uploadingSignature = true);
    try {
      await DoctorRepository().uploadSignature(bytes: bytes);
      ref.invalidate(myDoctorProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signature saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingSignature = false);
    }
  }

  Future<void> _deleteSignature() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Signature'),
        content: const Text('Are you sure you want to remove your digital signature?'),
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
    if (ok != true) return;
    setState(() => _uploadingSignature = true);
    try {
      await DoctorRepository().deleteSignature();
      ref.invalidate(myDoctorProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingSignature = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController();
    _specializationCtrl = TextEditingController();
    _licenseCtrl = TextEditingController();
    _qualificationCtrl = TextEditingController();
    _yearsCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
    _feeCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _specializationCtrl.dispose();
    _licenseCtrl.dispose();
    _qualificationCtrl.dispose();
    _yearsCtrl.dispose();
    _bioCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  void _populateControllers(DoctorProfile p) {
    _phoneCtrl.text = p.phone;
    _specializationCtrl.text = p.specialization;
    _licenseCtrl.text = p.licenseNumber;
    _qualificationCtrl.text = p.qualification;
    _yearsCtrl.text = p.yearsOfExperience > 0
        ? p.yearsOfExperience.toString()
        : '';
    _bioCtrl.text = p.bio;
    _feeCtrl.text =
        p.consultationFee > 0 ? p.consultationFee.toStringAsFixed(2) : '';
    _isAcceptingPatients = p.isAcceptingPatients;
    _selectedDays = List<String>.from(p.availableDays);
    _selectedLanguages = List<String>.from(p.languages);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'phone': _phoneCtrl.text.trim(),
        'specialization': _specializationCtrl.text.trim(),
        'license_number': _licenseCtrl.text.trim(),
        'qualification': _qualificationCtrl.text.trim(),
        'years_of_experience':
            int.tryParse(_yearsCtrl.text.trim()) ?? 0,
        'bio': _bioCtrl.text.trim(),
        'consultation_fee':
            double.tryParse(_feeCtrl.text.trim()) ?? 0,
        'is_accepting_patients': _isAcceptingPatients,
        'available_days': _selectedDays,
        'languages': _selectedLanguages,
      };
      await DoctorRepository().updateMyProfile(data);
      ref.invalidate(myDoctorProfileProvider);
      setState(() {
        _editing = false;
        _saving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myDoctorProfileProvider);

    return profileAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => app_error.AppErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(myDoctorProfileProvider),
      ),
      data: (profile) {
        // Populate only when switching to edit mode for the first time,
        // or after a save refresh (editing == false).
        if (!_editing && !_saving) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_editing) _populateControllers(profile);
          });
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, profile),
              const SizedBox(height: 24),
              if (_editing)
                _buildEditForm(context, profile)
              else
                _buildViewMode(context, profile),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // HEADER
  // =========================================================================

  Widget _buildHeader(BuildContext context, DoctorProfile profile) {
    final initials = _initials(profile.name);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar with camera overlay
            GestureDetector(
              onTap: _uploadingPicture ? null : _pickAndUploadPicture,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage: profile.profilePictureUrl != null
                        ? NetworkImage(profile.profilePictureUrl!)
                        : null,
                    child: profile.profilePictureUrl == null
                        ? Text(
                            initials,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      child: _uploadingPicture
                          ? const Padding(
                              padding: EdgeInsets.all(4),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt,
                              size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dr. ${profile.name}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.specialization.isNotEmpty
                        ? profile.specialization
                        : 'General Practitioner',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoChip(
                        icon: profile.isVerified
                            ? Icons.verified
                            : Icons.pending_outlined,
                        label: profile.isVerified ? 'Verified' : 'Pending',
                        color: profile.isVerified
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: profile.isAcceptingPatients
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        label: profile.isAcceptingPatients
                            ? 'Accepting Patients'
                            : 'Not Accepting',
                        color: profile.isAcceptingPatients
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (_editing)
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _editing = false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save'),
                  ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: () {
                  _populateControllers(profile);
                  setState(() => _editing = true);
                },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit Profile'),
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // VIEW MODE
  // =========================================================================

  Widget _buildViewMode(BuildContext context, DoctorProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Personal & Contact
        _SectionCard(
          title: 'Personal & Contact',
          icon: Icons.person_outline,
          children: [
            _DetailRow(label: 'Full Name', value: profile.name),
            _DetailRow(label: 'Email', value: profile.email),
            _DetailRow(
                label: 'Phone',
                value: profile.phone.isNotEmpty ? profile.phone : '—'),
            _DetailRow(
                label: 'Practice Type',
                value: _formatPracticeType(profile.practiceType)),
            if (profile.hospitalName != null)
              _DetailRow(label: 'Hospital', value: profile.hospitalName!),
          ],
        ),
        const SizedBox(height: 16),

        // Professional Details
        _SectionCard(
          title: 'Professional Details',
          icon: Icons.medical_services_outlined,
          children: [
            _DetailRow(
                label: 'Specialization',
                value: profile.specialization.isNotEmpty
                    ? profile.specialization
                    : '—'),
            _DetailRow(
                label: 'Qualification',
                value: profile.qualification.isNotEmpty
                    ? profile.qualification
                    : '—'),
            _DetailRow(
                label: 'License Number',
                value: profile.licenseNumber.isNotEmpty
                    ? profile.licenseNumber
                    : '—'),
            _DetailRow(
                label: 'Years of Experience',
                value: profile.yearsOfExperience > 0
                    ? '${profile.yearsOfExperience} years'
                    : '—'),
            _DetailRow(
                label: 'Consultation Fee',
                value: profile.consultationFee > 0
                    ? 'KES ${profile.consultationFee.toStringAsFixed(2)}'
                    : '—'),
          ],
        ),
        const SizedBox(height: 16),

        // Bio
        if (profile.bio.isNotEmpty)
          _SectionCard(
            title: 'Bio',
            icon: Icons.notes_outlined,
            children: [
              Text(profile.bio,
                  style: const TextStyle(fontSize: 14, height: 1.5)),
            ],
          ),
        if (profile.bio.isNotEmpty) const SizedBox(height: 16),

        // Availability
        _SectionCard(
          title: 'Availability',
          icon: Icons.schedule_outlined,
          children: [
            _DetailRow(
              label: 'Available Days',
              value: profile.availableDays.isNotEmpty
                  ? profile.availableDays.join(', ')
                  : '—',
            ),
            _DetailRow(
              label: 'Languages',
              value: profile.languages.isNotEmpty
                  ? profile.languages.join(', ')
                  : '—',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Digital Signature
        _SectionCard(
          title: 'Digital Signature',
          icon: Icons.draw_outlined,
          children: [
            if (profile.signatureUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 140),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.network(
                    profile.signatureUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined, size: 40),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'No signature set. Draw one below.',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed:
                      _uploadingSignature ? null : _openSignaturePad,
                  icon: _uploadingSignature
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.draw_outlined, size: 16),
                  label: Text(profile.signatureUrl != null
                      ? 'Redraw Signature'
                      : 'Draw Signature'),
                ),
                if (profile.signatureUrl != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed:
                        _uploadingSignature ? null : _deleteSignature,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // EDIT FORM
  // =========================================================================

  Widget _buildEditForm(BuildContext context, DoctorProfile profile) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact
          _SectionCard(
            title: 'Contact',
            icon: Icons.phone_outlined,
            children: [
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+254...',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Professional
          _SectionCard(
            title: 'Professional Details',
            icon: Icons.medical_services_outlined,
            children: [
              TextFormField(
                controller: _specializationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Specialization',
                  prefixIcon: Icon(Icons.local_hospital_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Required'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _qualificationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Qualification (e.g. MBChB, MD)',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _licenseCtrl,
                decoration: const InputDecoration(
                  labelText: 'License Number',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _yearsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Years of Experience',
                  prefixIcon: Icon(Icons.timeline_outlined),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (int.tryParse(v.trim()) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _feeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Consultation Fee (KES)',
                  prefixIcon: Icon(Icons.attach_money_outlined),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (double.tryParse(v.trim()) == null) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bio
          _SectionCard(
            title: 'Bio',
            icon: Icons.notes_outlined,
            children: [
              TextFormField(
                controller: _bioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bio / About',
                  hintText: 'Tell patients about yourself...',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Availability
          _SectionCard(
            title: 'Availability',
            icon: Icons.schedule_outlined,
            children: [
              // Accepting patients toggle
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Accepting New Patients'),
                subtitle: Text(
                  _isAcceptingPatients
                      ? 'Patients can book appointments'
                      : 'Appointments are paused',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                value: _isAcceptingPatients,
                activeColor: AppColors.success,
                onChanged: (v) =>
                    setState(() => _isAcceptingPatients = v),
              ),
              const Divider(),
              const SizedBox(height: 8),
              Text('Available Days',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _dayOptions.map((day) {
                  final selected = _selectedDays.contains(day);
                  return FilterChip(
                    label: Text(day.substring(0, 3),
                        style: TextStyle(
                            fontSize: 12,
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary)),
                    selected: selected,
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedDays.add(day);
                      } else {
                        _selectedDays.remove(day);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('Languages Spoken',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _languageOptions.map((lang) {
                  final selected = _selectedLanguages.contains(lang);
                  return FilterChip(
                    label: Text(lang,
                        style: TextStyle(
                            fontSize: 12,
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary)),
                    selected: selected,
                    selectedColor: AppColors.secondary,
                    checkmarkColor: Colors.white,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selectedLanguages.add(lang);
                      } else {
                        _selectedLanguages.remove(lang);
                      }
                    }),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Save button at the bottom too
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save Profile'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // HELPERS
  // =========================================================================

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'D';
  }

  String _formatPracticeType(String type) {
    switch (type) {
      case 'independent':
        return 'Independent';
      case 'hospital':
        return 'Hospital-based';
      case 'locum':
        return 'Locum';
      default:
        return type;
    }
  }
}

// ---------------------------------------------------------------------------
// Reusable widgets
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Signature Pad Dialog
// ---------------------------------------------------------------------------

class _SignaturePadDialog extends StatefulWidget {
  const _SignaturePadDialog();

  @override
  State<_SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<_SignaturePadDialog> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _current = [];
  final GlobalKey _repaintKey = GlobalKey();
  bool _exporting = false;

  Future<Uint8List?> _export() async {
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _strokes.isEmpty && _current.isEmpty;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                children: [
                  Icon(Icons.draw_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text('Draw Your Signature',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Sign your name in the box below using your mouse or finger.',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),

              // Drawing canvas
              RepaintBoundary(
                key: _repaintKey,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: GestureDetector(
                      onPanStart: (d) {
                        setState(() {
                          _current = [d.localPosition];
                        });
                      },
                      onPanUpdate: (d) {
                        setState(() {
                          _current.add(d.localPosition);
                        });
                      },
                      onPanEnd: (_) {
                        setState(() {
                          if (_current.isNotEmpty) {
                            _strokes.add(List.from(_current));
                          }
                          _current = [];
                        });
                      },
                      child: CustomPaint(
                        painter: _SignaturePainter(
                            strokes: _strokes, current: _current),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Action row
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _strokes.clear();
                      _current = [];
                    }),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Clear'),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: (isEmpty || _exporting)
                        ? null
                        : () async {
                            setState(() => _exporting = true);
                            final bytes = await _export();
                            if (context.mounted) {
                              Navigator.pop(context, bytes);
                            }
                          },
                    icon: _exporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 16),
                    label: const Text('Save Signature'),
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

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> current;

  const _SignaturePainter({required this.strokes, required this.current});

  @override
  void paint(Canvas canvas, Size size) {
    // White background so the exported PNG is clean
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );
    final paint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void drawStroke(List<Offset> pts) {
      if (pts.length < 2) {
        if (pts.length == 1) canvas.drawCircle(pts[0], 1.5, paint);
        return;
      }
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final s in strokes) {
      drawStroke(s);
    }
    drawStroke(current);
  }

  @override
  bool shouldRepaint(_SignaturePainter old) =>
      old.strokes != strokes || old.current != current;
}
