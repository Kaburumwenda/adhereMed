import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../core/theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/loading_widget.dart';
import '../utils/prescription_pdf.dart';
import '../models/prescription_model.dart';
import '../repository/prescription_repository.dart';
import '../../doctors/repository/doctor_repository.dart';
import '../../doctors/models/doctor_model.dart';

/// Searches the global medications catalog.
Future<List<Map<String, dynamic>>> _searchMedications(String query) async {
  if (query.length < 2) return [];
  try {
    final response = await ApiClient.instance
        .get('/medications/search/', queryParameters: {'q': query});
    final data = response.data;
    // Handle both paginated ({"results": [...]}) and plain list responses
    final List results =
        data is List ? data : (data['results'] as List?) ?? [];
    return results.cast<Map<String, dynamic>>();
  } catch (e) {
    debugPrint('Medication search error: $e');
    return [];
  }
}

class PrescriptionFormScreen extends ConsumerStatefulWidget {
  final String? prescriptionId;
  const PrescriptionFormScreen({super.key, this.prescriptionId});

  @override
  ConsumerState<PrescriptionFormScreen> createState() =>
      _PrescriptionFormScreenState();
}

class _ItemControllers {
  final TextEditingController medicationName;
  final TextEditingController dosage;
  final TextEditingController frequency;
  final TextEditingController duration;
  final TextEditingController quantity;
  final TextEditingController instructions;
  final TextEditingController schedule;
  final TextEditingController refills;

  _ItemControllers({
    String name = '',
    String dos = '',
    String freq = '',
    String dur = '',
    String qty = '1',
    String inst = '',
    String sched = '',
    String refs = '0',
  })  : medicationName = TextEditingController(text: name),
        dosage = TextEditingController(text: dos),
        frequency = TextEditingController(text: freq),
        duration = TextEditingController(text: dur),
        quantity = TextEditingController(text: qty),
        instructions = TextEditingController(text: inst),
        schedule = TextEditingController(text: sched),
        refills = TextEditingController(text: refs);

  factory _ItemControllers.fromItem(PrescriptionItem item) {
    return _ItemControllers(
      name: item.medicationName,
      dos: item.dosage,
      freq: item.frequency,
      dur: item.duration,
      qty: item.quantity.toString(),
      inst: item.instructions ?? '',
      sched: item.schedule ?? '',
      refs: item.refills.toString(),
    );
  }

  void dispose() {
    medicationName.dispose();
    dosage.dispose();
    frequency.dispose();
    duration.dispose();
    quantity.dispose();
    instructions.dispose();
    schedule.dispose();
    refills.dispose();
  }
}

class _PrescriptionFormScreenState
    extends ConsumerState<PrescriptionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = PrescriptionRepository();

  // ── Presets ──────────────────────────────────────────────────────────────
  static const _dosagePresets = [
    '1 tablet', '2 tablets', '3 tablets',
    '½ tablet', '1 capsule', '2 capsules',
    '5 ml', '10 ml', '15 ml', '20 ml',
    '1 drop', '2 drops', '1 sachet', '1 patch',
    '100 mg', '200 mg', '250 mg', '400 mg',
    '500 mg', '600 mg', '750 mg', '1000 mg',
  ];
  static const _freqPresets = [
    'OD', 'BD', 'TDS', 'QID', 'Q6H', 'Q8H', 'Q12H', 'PRN', 'Weekly',
  ];
  static const _schedulePresets = [
    'Morning', 'Evening', 'Night',
    'Morning & Night', 'Morning, Afternoon & Night',
    'Before meals', 'After meals', 'With meals', 'At bedtime',
  ];
  static const _instructionPresets = [
    'Take with food', 'Take on empty stomach', 'Take with plenty of water',
    'Swallow whole', 'Do not crush or chew', 'Avoid alcohol',
    'Apply to affected area', 'For external use only',
    'Shake well before use', 'Keep refrigerated',
  ];

  // Doctor profile (loaded once on init)
  DoctorProfile? _doctorProfile;
  bool _loadingDoctor = false;

  final _patientSearchCtrl = TextEditingController();
  int? _selectedPatientId;
  String? _selectedPatientName;
  String? _selectedPatientPhone;
  String? _selectedPatientEmail;
  String? _selectedPatientNationalId;
  List<String> _selectedPatientAllergies = [];
  List<String> _selectedPatientConditions = [];
  String? _selectedPatientInsuranceProvider;
  String? _selectedPatientInsuranceNumber;
  List<Map<String, dynamic>> _patientResults = [];
  bool _searchingPatients = false;
  Timer? _debounce;

  final _notesCtrl = TextEditingController();
  String _status = 'active';

  final List<_ItemControllers> _items = [];

  bool _loading = false;
  bool _initialLoading = false;

  bool get _isEditing => widget.prescriptionId != null;

  @override
  void initState() {
    super.initState();
    _loadDoctorProfile();
    if (_isEditing) {
      _loadPrescription();
    } else {
      _items.add(_ItemControllers());
    }
  }

  Future<void> _loadDoctorProfile() async {
    setState(() => _loadingDoctor = true);
    try {
      final profile = await DoctorRepository().getMyProfile();
      if (!mounted) return;
      setState(() => _doctorProfile = profile);
    } catch (_) {
      // Non-critical — show nothing if unavailable
    } finally {
      if (mounted) setState(() => _loadingDoctor = false);
    }
  }

  @override
  void dispose() {
    _patientSearchCtrl.dispose();
    _notesCtrl.dispose();
    _debounce?.cancel();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPrescription() async {
    setState(() => _initialLoading = true);
    try {
      final p = await _repo.getDetail(int.parse(widget.prescriptionId!));
      _selectedPatientId = p.patientId;
      _selectedPatientName = p.patientName ?? 'Patient #${p.patientId}';
      _selectedPatientPhone = p.patientPhone;
      _selectedPatientEmail = p.patientEmail;
      _patientSearchCtrl.text = _selectedPatientName!;
      _notesCtrl.text = p.notes ?? '';
      _status = p.status;
      for (final item in p.items) {
        _items.add(_ItemControllers.fromItem(item));
      }
      if (_items.isEmpty) _items.add(_ItemControllers());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _initialLoading = false);
  }

  Future<void> _searchPatients(String query) async {
    if (query.length < 2) {
      setState(() => _patientResults = []);
      return;
    }
    setState(() => _searchingPatients = true);
    try {
      final response = await ApiClient.instance
          .get('/patients/', queryParameters: {'search': query, 'page_size': 10});
      final results = (response.data['results'] as List?) ?? [];
      setState(() {
        _patientResults = results
            .map<Map<String, dynamic>>((p) => {
                  'id': p['id'],
                  'name':
                      '${p['user']?['first_name'] ?? ''} ${p['user']?['last_name'] ?? ''}'
                          .trim(),
                  'patient_number': p['patient_number'] ?? '',
                  'national_id': p['national_id'] ?? '',
                  'phone': p['user']?['phone'] ?? '',
                  'email': p['user']?['email'] ?? '',
                  'allergies': p['allergies'] ?? [],
                  'chronic_conditions': p['chronic_conditions'] ?? [],
                  'insurance_provider': p['insurance_provider'] ?? '',
                  'insurance_number': p['insurance_number'] ?? '',
                })
            .toList();
      });
    } catch (e) {
      debugPrint('Patient search error: $e');
    }
    if (mounted) setState(() => _searchingPatients = false);
  }

  void _onPatientSearchChanged(String value) {
    if (_selectedPatientId != null && value != _selectedPatientName) {
      _selectedPatientId = null;
      _selectedPatientName = null;
      _selectedPatientPhone = null;
      _selectedPatientEmail = null;
      _selectedPatientNationalId = null;
      _selectedPatientAllergies = [];
      _selectedPatientConditions = [];
      _selectedPatientInsuranceProvider = null;
      _selectedPatientInsuranceNumber = null;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchPatients(value);
    });
  }

  void _selectPatient(Map<String, dynamic> patient) {
    setState(() {
      _selectedPatientId = patient['id'] as int;
      _selectedPatientName = patient['name'] as String;
      _selectedPatientPhone = patient['phone'] as String?;
      _selectedPatientEmail = patient['email'] as String?;
      _selectedPatientNationalId = patient['national_id'] as String?;
      _selectedPatientAllergies =
          List<String>.from(patient['allergies'] as List? ?? []);
      _selectedPatientConditions =
          List<String>.from(patient['chronic_conditions'] as List? ?? []);
      _selectedPatientInsuranceProvider =
          patient['insurance_provider'] as String?;
      _selectedPatientInsuranceNumber =
          patient['insurance_number'] as String?;
      _patientSearchCtrl.text = _selectedPatientName!;
      _patientResults = [];
    });
  }

  void _addItem() {
    _items.add(_ItemControllers());
    setState(() {});
  }

  void _removeItem(int index) {
    _items[index].dispose();
    _items.removeAt(index);
    setState(() {});
  }

  // ── PDF helpers ───────────────────────────────────────────────────────────────
  bool _generatingPdf = false;

  Future<void> _buildAndPrint({required bool share}) async {
    final rxId = widget.prescriptionId;
    if (rxId == null) return;
    setState(() => _generatingPdf = true);
    try {
      final prescription = await _repo.getDetail(int.parse(rxId));
      // Resolve left logo and info from already-loaded doctor profile
      final profile = _doctorProfile;
      Uint8List? leftLogo;
      String? leftName;
      String? leftEmail;
      String? leftLocation;
      if (profile != null) {
        if (profile.practiceType.toLowerCase() == 'independent') {
          if (profile.profilePictureUrl?.isNotEmpty == true) {
            leftLogo = await fetchNetworkImageBytes(profile.profilePictureUrl!);
          }
          leftName = profile.name.isNotEmpty ? profile.name : null;
          leftEmail = profile.email.isNotEmpty ? profile.email : 'info@example.com';
          leftLocation = 'Kenya';
        } else {
          leftName = profile.hospitalName?.isNotEmpty == true
              ? profile.hospitalName
              : null;
          leftEmail = 'info@example.com';
          leftLocation = 'Kenya';
        }
      }
      if (share) {
        final bytes = await buildPrescriptionPdf(
          prescription: prescription,
          leftLogoBytes: leftLogo,
          leftName: leftName,
          leftEmail: leftEmail,
          leftLocation: leftLocation,
        );
        await Printing.sharePdf(
            bytes: bytes, filename: 'Prescription_${prescription.id}.pdf');
      } else {
        await Printing.layoutPdf(
          onLayout: (_) => buildPrescriptionPdf(
            prescription: prescription,
            leftLogoBytes: leftLogo,
            leftName: leftName,
            leftEmail: leftEmail,
            leftLocation: leftLocation,
          ),
          name: 'Prescription_${prescription.id}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not generate PDF: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
    if (mounted) setState(() => _generatingPdf = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a patient')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final data = {
        'patient': _selectedPatientId,
        'status': _status,
        'notes': _notesCtrl.text,
        'items': _items
            .map((i) => {
                  'medication_name': i.medicationName.text,
                  'dosage': i.dosage.text,
                  'frequency': i.frequency.text,
                  'duration': i.duration.text,
                  'quantity': int.tryParse(i.quantity.text) ?? 1,
                  'instructions': i.instructions.text,
                  'schedule': i.schedule.text,
                  'refills': int.tryParse(i.refills.text) ?? 0,
                })
            .toList(),
      };
      if (_isEditing) {
        await _repo.update(int.parse(widget.prescriptionId!), data);
      } else {
        await _repo.create(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                _isEditing ? 'Prescription updated' : 'Prescription created')));
        context.go('/prescriptions');
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      String message = 'Failed to save prescription.';
      if (data is Map) {
        final errors = data.entries
            .map((e) =>
                e.value is List ? (e.value as List).join(', ') : '${e.value}')
            .join('\n');
        if (errors.isNotEmpty) message = errors;
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Widget _buildDoctorInfoCard() {
    final profile = _doctorProfile;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.medical_services_outlined,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Text('Prescribing Doctor',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (_loadingDoctor) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ],
            ),
            const SizedBox(height: 16),
            if (profile == null && !_loadingDoctor)
              Text('Profile not available',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13))
            else if (profile != null) ...[
              Wrap(
                spacing: 32,
                runSpacing: 12,
                children: [
                  _DoctorInfoItem(
                    icon: Icons.badge_outlined,
                    label: 'Name',
                    value: profile.name.isNotEmpty ? profile.name : '—',
                  ),
                  _DoctorInfoItem(
                    icon: Icons.card_membership_outlined,
                    label: 'License No.',
                    value: profile.licenseNumber?.isNotEmpty == true
                        ? profile.licenseNumber!
                        : '—',
                  ),
                  _DoctorInfoItem(
                    icon: Icons.local_hospital_outlined,
                    label: 'Practice Type',
                    value: profile.practiceType?.isNotEmpty == true
                        ? profile.practiceType!
                        : '—',
                  ),
                  _DoctorInfoItem(
                    icon: Icons.science_outlined,
                    label: 'Specialization',
                    value: profile.specialization?.isNotEmpty == true
                        ? profile.specialization!
                        : '—',
                  ),
                ],
              ),
              if (profile.signatureUrl != null) ...[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.draw_outlined,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Signature',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            height: 60,
                            width: 180,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Image.network(
                              profile.signatureUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image_outlined,
                                      size: 24)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 14, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Text('No digital signature set — go to My Profile to add one.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) return const LoadingWidget();

    // ── Profile incomplete guard ───────────────────────────────────────
    final profile = _doctorProfile;
    if (!_loadingDoctor && profile != null) {
      final missingLicense = (profile.licenseNumber ?? '').trim().isEmpty;
      final missingSignature = (profile.signatureUrl ?? '').trim().isEmpty;
      if (missingLicense || missingSignature) {
        final missing = [
          if (missingLicense) 'License Number',
          if (missingSignature) 'Signature',
        ];
        return _ProfileIncompleteScreen(missingFields: missing);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isEditing ? 'Edit Prescription' : 'Write Prescription',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // ── Doctor Info Card ──
          _buildDoctorInfoCard(),
          const SizedBox(height: 16),

          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient selection card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Patient',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _patientSearchCtrl,
                          decoration: InputDecoration(
                            labelText: 'Search by name, patient number or national ID...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchingPatients
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)))
                                : _selectedPatientId != null
                                    ? Icon(Icons.check_circle,
                                        color: AppColors.success)
                                    : null,
                          ),
                          onChanged: _onPatientSearchChanged,
                          validator: (_) => _selectedPatientId == null
                              ? 'Please search and select a patient'
                              : null,
                        ),
                        if (_patientResults.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _patientResults.length,
                              itemBuilder: (context, index) {
                                final p = _patientResults[index];
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor:
                                        AppColors.primary.withValues(alpha: 0.1),
                                    child: Text(
                                      ((p['name'] as String?) ?? '?')
                                          .characters
                                          .first
                                          .toUpperCase(),
                                      style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12),
                                    ),
                                  ),
                                  title: Text(p['name'] as String? ?? ''),
                                  subtitle: Text(
                                    [p['patient_number'], if ((p['national_id'] as String? ?? '').isNotEmpty) 'NID: ${p['national_id']}'].join(' • '),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                  ),
                                  onTap: () => _selectPatient(p),
                                );
                              },
                            ),
                          ),
                        if (_selectedPatientId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Chip(
                              avatar: Icon(Icons.person,
                                  size: 16, color: AppColors.primary),
                              label: Text(
                                  '$_selectedPatientName (ID: $_selectedPatientId)'),
                              onDeleted: () => setState(() {
                                _selectedPatientId = null;
                                _selectedPatientName = null;
                                _selectedPatientPhone = null;
                                _selectedPatientEmail = null;
                                _selectedPatientNationalId = null;
                                _selectedPatientAllergies = [];
                                _selectedPatientConditions = [];
                                _selectedPatientInsuranceProvider = null;
                                _selectedPatientInsuranceNumber = null;
                                _patientSearchCtrl.clear();
                              }),
                            ),
                          ),
                        if (_selectedPatientId != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Contact row ──
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 10,
                                  children: [
                                    _PatientInfoChip(
                                      icon: Icons.badge_outlined,
                                      label: 'National ID',
                                      value: (_selectedPatientNationalId ?? '').isNotEmpty
                                          ? _selectedPatientNationalId!
                                          : 'None',
                                    ),
                                    _PatientInfoChip(
                                      icon: Icons.phone_outlined,
                                      label: 'Phone',
                                      value: (_selectedPatientPhone ?? '').isNotEmpty
                                          ? _selectedPatientPhone!
                                          : 'None',
                                    ),
                                    _PatientInfoChip(
                                      icon: Icons.email_outlined,
                                      label: 'Email',
                                      value: (_selectedPatientEmail ?? '').isNotEmpty
                                          ? _selectedPatientEmail!
                                          : 'None',
                                    ),
                                  ],
                                ),
                                // ── Allergies ──
                                const SizedBox(height: 12),
                                _PatientInfoSection(
                                  icon: Icons.warning_amber_rounded,
                                  iconColor: const Color(0xFFEF4444),
                                  label: 'Allergies',
                                  chips: _selectedPatientAllergies,
                                  chipColor: const Color(0xFFEF4444),
                                ),
                                // ── Chronic conditions ──
                                const SizedBox(height: 12),
                                _PatientInfoSection(
                                  icon: Icons.monitor_heart_outlined,
                                  iconColor: const Color(0xFFF59E0B),
                                  label: 'Chronic Conditions',
                                  chips: _selectedPatientConditions,
                                  chipColor: const Color(0xFFF59E0B),
                                ),
                                // ── Insurance ──
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.health_and_safety_outlined,
                                        size: 15,
                                        color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text('Insurance',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    _PatientInfoChip(
                                      icon: Icons.business_outlined,
                                      label: 'Provider',
                                      value: (_selectedPatientInsuranceProvider ?? '').isNotEmpty
                                          ? _selectedPatientInsuranceProvider!
                                          : 'None',
                                    ),
                                    _PatientInfoChip(
                                      icon: Icons.confirmation_number_outlined,
                                      label: 'Policy No.',
                                      value: (_selectedPatientInsuranceNumber ?? '').isNotEmpty
                                          ? _selectedPatientInsuranceNumber!
                                          : 'None',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            initialValue: _status,
                            decoration:
                                const InputDecoration(labelText: 'Status'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'active', child: Text('Active')),
                              DropdownMenuItem(
                                  value: 'dispensed',
                                  child: Text('Dispensed')),
                              DropdownMenuItem(
                                  value: 'cancelled',
                                  child: Text('Cancelled')),
                              DropdownMenuItem(
                                  value: 'expired',
                                  child: Text('Expired')),
                            ],
                            onChanged: (v) =>
                                setState(() => _status = v ?? 'active'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Notes'),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Medication items card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Medications',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            const Spacer(),
                            FilledButton.icon(
                              onPressed: _addItem,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add Medication'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...List.generate(_items.length, (i) {
                          final item = _items[i];
                          return Card(
                            color: AppColors.background,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Text('Medication ${i + 1}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      const Spacer(),
                                      if (_items.length > 1)
                                        IconButton(
                                          icon: Icon(Icons.close,
                                              size: 18,
                                              color: AppColors.error),
                                          onPressed: () => _removeItem(i),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // ── Row 1: Medication name ────────────
                                      SizedBox(
                                        width: 300,
                                        child: _MedicationAutocomplete(
                                          controller: item.medicationName,
                                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      // ── Row 2: Dosage ─────────────────────
                                      Text('Dosage',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                      const SizedBox(height: 6),
                                      _QuickChips(
                                        options: _dosagePresets,
                                        selected: item.dosage.text,
                                        onSelect: (v) => setState(() => item.dosage.text = v),
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        width: 180,
                                        child: TextFormField(
                                          controller: item.dosage,
                                          decoration: const InputDecoration(labelText: 'Dosage', isDense: true),
                                          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      // ── Row 3: Frequency ─────────────────
                                      Text('Frequency',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                      const SizedBox(height: 6),
                                      _QuickChips(
                                        options: _freqPresets,
                                        selected: item.frequency.text,
                                        onSelect: (v) => setState(() => item.frequency.text = v),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: [
                                          SizedBox(
                                            width: 150,
                                            child: TextFormField(
                                              controller: item.frequency,
                                              decoration: const InputDecoration(labelText: 'Frequency', isDense: true),
                                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 130,
                                            child: TextFormField(
                                              controller: item.duration,
                                              decoration: const InputDecoration(
                                                labelText: 'Duration',
                                                hintText: 'e.g. 7 days',
                                                isDense: true,
                                              ),
                                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 90,
                                            child: TextFormField(
                                              controller: item.quantity,
                                              decoration: const InputDecoration(
                                                labelText: 'Qty',
                                                isDense: true,
                                              ),
                                              keyboardType: TextInputType.number,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      // ── Row 3: Instructions ───────────────
                                      Text('Instructions',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                      const SizedBox(height: 6),
                                      _QuickChips(
                                        options: _instructionPresets,
                                        selected: item.instructions.text,
                                        onSelect: (v) => setState(() => item.instructions.text = v),
                                      ),
                                      const SizedBox(height: 6),
                                      TextFormField(
                                        controller: item.instructions,
                                        decoration: const InputDecoration(
                                          labelText: 'Instructions (or type custom)',
                                          isDense: true,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      // ── Row 4: Schedule + Refills ─────────
                                      Text('Schedule',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                                      const SizedBox(height: 6),
                                      _QuickChips(
                                        options: _schedulePresets,
                                        selected: item.schedule.text,
                                        onSelect: (v) => setState(() => item.schedule.text = v),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: [
                                          SizedBox(
                                            width: 220,
                                            child: TextFormField(
                                              controller: item.schedule,
                                              decoration: const InputDecoration(
                                                labelText: 'Schedule (or type custom)',
                                                isDense: true,
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 80,
                                            child: TextFormField(
                                              controller: item.refills,
                                              decoration: const InputDecoration(labelText: 'Refills', isDense: true),
                                              keyboardType: TextInputType.number,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    FilledButton(
                      onPressed: _loading ? null : _save,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : Text(_isEditing
                              ? 'Update Prescription'
                              : 'Create Prescription'),
                    ),
                    const SizedBox(width: 12),
                    if (_isEditing) ...[  
                      OutlinedButton.icon(
                        onPressed:
                            _generatingPdf ? null : () => _buildAndPrint(share: false),
                        icon: _generatingPdf
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Print'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed:
                            _generatingPdf ? null : () => _buildAndPrint(share: true),
                        icon: _generatingPdf
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download PDF'),
                      ),
                      const SizedBox(width: 12),
                    ],
                    OutlinedButton(
                      onPressed: () => context.go('/prescriptions'),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Doctor Info Item (label + value row) ──
// ── Quick chip selector ───────────────────────────────────────────────────────

class _QuickChips extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _QuickChips({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.map((opt) {
        final isSelected =
            selected.trim().toLowerCase() == opt.toLowerCase();
        return GestureDetector(
          onTap: () => onSelect(opt),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.border,
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Profile Incomplete blocking screen ────────────────────────────────────────
class _ProfileIncompleteScreen extends StatelessWidget {
  final List<String> missingFields;
  const _ProfileIncompleteScreen({required this.missingFields});

  @override
  Widget build(BuildContext context) {
    final fieldList = missingFields.join(' and ');
    final verb = missingFields.length > 1 ? 'are' : 'is';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFFED7AA), width: 2),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFF97316), size: 48),
            ),
            const SizedBox(height: 24),
            Text('Profile Incomplete',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Text(
              '$fieldList $verb required before you can write a prescription.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Please update your doctor profile and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.push('/doctor-profile'),
              icon: const Icon(Icons.person_outline),
              label: const Text('Go to My Profile'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text('Go Back',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Patient info helper widgets ───────────────────────────────────────────────

class _PatientInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PatientInfoChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ],
        ),
      ],
    );
  }
}

class _PatientInfoSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final List<String> chips;
  final Color chipColor;

  const _PatientInfoSection({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.chips,
    required this.chipColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 6),
        chips.isEmpty
            ? Text('None',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic))
            : Wrap(
                spacing: 6,
                runSpacing: 6,
                children: chips
                    .map((c) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: chipColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: chipColor.withValues(alpha: 0.30)),
                          ),
                          child: Text(c,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: chipColor,
                                  fontWeight: FontWeight.w500)),
                        ))
                    .toList(),
              ),
      ],
    );
  }
}

// ── Doctor info helper widget ─────────────────────────────────────────────────

class _DoctorInfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DoctorInfoItem(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ],
        ),
      ],
    );
  }
}

/// Autocomplete medication field. Searches the global catalog as the user
/// types. If no match is found, the user can keep their custom entry.
class _MedicationAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const _MedicationAutocomplete({
    required this.controller,
    this.validator,
  });

  @override
  State<_MedicationAutocomplete> createState() =>
      _MedicationAutocompleteState();
}

class _MedicationAutocompleteState extends State<_MedicationAutocomplete> {
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _showDropdown = false;
  Timer? _debounce;
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Delay to allow tap on dropdown item
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _removeOverlay();
      });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (value.length < 2) {
        setState(() {
          _results = [];
          _showDropdown = false;
        });
        _removeOverlay();
        return;
      }
      setState(() => _searching = true);
      final results = await _searchMedications(value);
      if (mounted) {
        setState(() {
          _results = results;
          _searching = false;
          _showDropdown = results.isNotEmpty;
        });
        if (_showDropdown) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      }
    });
  }

  void _selectMedication(Map<String, dynamic> med) {
    final label = med['label'] as String? ?? med['generic_name'] as String? ?? '';
    widget.controller.text = label;
    setState(() {
      _showDropdown = false;
      _results = [];
    });
    _removeOverlay();
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    final surfaceColor = AppColors.surface;
    final borderColor = AppColors.border;
    final textPrimary = AppColors.textPrimary;
    final textSecondary = AppColors.textSecondary;
    final primaryColor = AppColors.primary;
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 300,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 48),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            color: surfaceColor,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _results.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: borderColor),
                itemBuilder: (context, index) {
                  final med = _results[index];
                  final label = med['label'] as String? ?? med['generic_name'] ?? '';
                  final category = med['category'] as String? ?? '';
                  return InkWell(
                    onTap: () => _selectMedication(med),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.medication_rounded,
                                size: 14, color: primaryColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                if (category.isNotEmpty)
                                  Text(category,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: 'Medication Name',
          isDense: true,
          prefixIcon: const Icon(Icons.medication_outlined, size: 20),
          suffixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
          helperText: 'Type to search or enter custom name',
          helperStyle: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        onChanged: _onChanged,
        validator: widget.validator,
      ),
    );
  }
}
