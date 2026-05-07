import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart';
import '../../../features/clinical_catalog/models/clinical_catalog_models.dart';
import '../../../features/clinical_catalog/repository/clinical_catalog_repository.dart';
import '../models/patient_model.dart';
import '../repository/patient_repository.dart';

// ── Provider ─────────────────────────────────────────────────────────────────

final myPatientProfileProvider = FutureProvider.autoDispose<Patient>((ref) {
  return PatientRepository().getMyProfile();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class PatientProfileScreen extends ConsumerStatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  ConsumerState<PatientProfileScreen> createState() =>
      _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen> {
  bool _editing = false;
  bool _saving = false;
  String? _error;

  final _formKey = GlobalKey<FormState>();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _emergencyRelationCtrl = TextEditingController();
  final _insuranceProviderCtrl = TextEditingController();
  final _insurancePolicyCtrl = TextEditingController();

  String? _gender;
  String? _bloodGroup;
  DateTime? _dateOfBirth;
  Set<String> _selectedAllergies = {};
  Set<String> _selectedConditions = {};

  List<AllergyModel> _allergyCatalog = [];
  List<ChronicConditionModel> _conditionCatalog = [];
  bool _catalogLoaded = false;

  static const _genders = ['male', 'female', 'other'];
  static const _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl, _lastNameCtrl, _emailCtrl, _phoneCtrl, _idNumberCtrl,
      _addressCtrl, _emergencyNameCtrl,
      _emergencyPhoneCtrl, _emergencyRelationCtrl, _insuranceProviderCtrl,
      _insurancePolicyCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _populateFrom(Patient p) {
    _firstNameCtrl.text = p.firstName;
    _lastNameCtrl.text = p.lastName;
    _emailCtrl.text = p.email ?? '';
    _phoneCtrl.text = p.phone ?? '';
    _idNumberCtrl.text = p.idNumber ?? '';
    _addressCtrl.text = p.address ?? '';
    _emergencyNameCtrl.text = p.emergencyContactName ?? '';
    _emergencyPhoneCtrl.text = p.emergencyContactPhone ?? '';
    _emergencyRelationCtrl.text = p.emergencyContactRelation ?? '';
    _insuranceProviderCtrl.text = p.insuranceProvider ?? '';
    _insurancePolicyCtrl.text = p.insurancePolicyNumber ?? '';
    _gender = (p.gender?.isEmpty ?? true) ? null : p.gender;
    _bloodGroup = (p.bloodGroup?.isEmpty ?? true) ? null : p.bloodGroup;
    _dateOfBirth =
        p.dateOfBirth != null ? DateTime.tryParse(p.dateOfBirth!) : null;
    _selectedAllergies = _splitToSet(p.allergies);
    _selectedConditions = _splitToSet(p.chronicConditions);
  }

  Set<String> _splitToSet(String? val) {
    if (val == null || val.trim().isEmpty) return {};
    return val.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  Future<void> _loadCatalog() async {
    if (_catalogLoaded) return;
    try {
      final repo = ClinicalCatalogRepository();
      final results = await Future.wait([
        repo.getAllergies(isActive: true, pageSize: 500),
        repo.getConditions(isActive: true, pageSize: 500),
      ]);
      if (mounted) {
        setState(() {
          _allergyCatalog = results[0] as List<AllergyModel>;
          _conditionCatalog = results[1] as List<ChronicConditionModel>;
          _catalogLoaded = true;
        });
      }
    } catch (_) {
      // Catalog load failure is non-fatal; fields degrade gracefully
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    final data = <String, dynamic>{
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      if (_emailCtrl.text.trim().isNotEmpty) 'email': _emailCtrl.text.trim(),
      if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
      'gender': _gender,
      'date_of_birth': _dateOfBirth != null
          ? '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}'
          : null,
      'national_id': _idNumberCtrl.text.trim(),
      'blood_type': _bloodGroup,
      'address': _addressCtrl.text.trim(),
      'allergies': _selectedAllergies.toList(),
      'chronic_conditions': _selectedConditions.toList(),
      'emergency_contact_name': _emergencyNameCtrl.text.trim(),
      'emergency_contact_phone': _emergencyPhoneCtrl.text.trim(),
      'emergency_contact_relation': _emergencyRelationCtrl.text.trim(),
      'insurance_provider': _insuranceProviderCtrl.text.trim(),
      'insurance_number': _insurancePolicyCtrl.text.trim(),
    };

    try {
      await PatientRepository().updateMyProfile(data);
      ref.invalidate(myPatientProfileProvider);
      if (mounted) {
        setState(() { _editing = false; _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myPatientProfileProvider);

    return profileAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => AppErrorWidget(
        message: e.toString(),
        onRetry: () => ref.invalidate(myPatientProfileProvider),
      ),
      data: (patient) {
          if (!_editing) _populateFrom(patient);
          return _ProfileBody(
          patient: patient,
          editing: _editing,
          saving: _saving,
          error: _error,
          formKey: _formKey,
          firstNameCtrl: _firstNameCtrl,
          lastNameCtrl: _lastNameCtrl,
          emailCtrl: _emailCtrl,
          phoneCtrl: _phoneCtrl,
          idNumberCtrl: _idNumberCtrl,
          addressCtrl: _addressCtrl,
          emergencyNameCtrl: _emergencyNameCtrl,
          emergencyPhoneCtrl: _emergencyPhoneCtrl,
          emergencyRelationCtrl: _emergencyRelationCtrl,
          insuranceProviderCtrl: _insuranceProviderCtrl,
          insurancePolicyCtrl: _insurancePolicyCtrl,
          gender: _gender,
          bloodGroup: _bloodGroup,
          dateOfBirth: _dateOfBirth,
          genders: _genders,
          bloodGroups: _bloodGroups,
          selectedAllergies: _selectedAllergies,
          selectedConditions: _selectedConditions,
          allergyCatalog: _allergyCatalog,
          conditionCatalog: _conditionCatalog,
          onAllergiesChanged: (v) => setState(() => _selectedAllergies = v),
          onConditionsChanged: (v) => setState(() => _selectedConditions = v),
          onGenderChanged: (v) => setState(() => _gender = v),
          onBloodGroupChanged: (v) => setState(() => _bloodGroup = v),
          onPickDate: _pickDate,
          onEdit: () {
            _populateFrom(patient);
            _loadCatalog();
            setState(() { _editing = true; _error = null; });
          },
          onCancel: () => setState(() { _editing = false; _error = null; }),
          onSave: _save,
        );
      },
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  final Patient patient;
  final bool editing;
  final bool saving;
  final String? error;
  final GlobalKey<FormState> formKey;

  // Controllers
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController idNumberCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController emergencyNameCtrl;
  final TextEditingController emergencyPhoneCtrl;
  final TextEditingController emergencyRelationCtrl;
  final TextEditingController insuranceProviderCtrl;
  final TextEditingController insurancePolicyCtrl;

  // Dropdowns / date
  final String? gender;
  final String? bloodGroup;
  final DateTime? dateOfBirth;
  final List<String> genders;
  final List<String> bloodGroups;

  // Multi-select
  final Set<String> selectedAllergies;
  final Set<String> selectedConditions;
  final List<AllergyModel> allergyCatalog;
  final List<ChronicConditionModel> conditionCatalog;
  final ValueChanged<Set<String>> onAllergiesChanged;
  final ValueChanged<Set<String>> onConditionsChanged;

  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<String?> onBloodGroupChanged;

  // Callbacks
  final VoidCallback onPickDate;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _ProfileBody({
    required this.patient,
    required this.editing,
    required this.saving,
    required this.error,
    required this.formKey,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.idNumberCtrl,
    required this.addressCtrl,
    required this.emergencyNameCtrl,
    required this.emergencyPhoneCtrl,
    required this.emergencyRelationCtrl,
    required this.insuranceProviderCtrl,
    required this.insurancePolicyCtrl,
    required this.gender,
    required this.bloodGroup,
    required this.dateOfBirth,
    required this.genders,
    required this.bloodGroups,
    required this.selectedAllergies,
    required this.selectedConditions,
    required this.allergyCatalog,
    required this.conditionCatalog,
    required this.onAllergiesChanged,
    required this.onConditionsChanged,
    required this.onGenderChanged,
    required this.onBloodGroupChanged,
    required this.onPickDate,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (error != null) ...[
                    _ErrorBanner(message: error!),
                    const SizedBox(height: 16),
                  ],
                  _buildAvatarCard(),
                  const SizedBox(height: 20),
                  _Section(
                    title: 'Personal Information',
                    icon: Icons.person_outline,
                    accentColor: const Color(0xFF0D9488),
                    children: [
                      _row([
                        _Field(ctrl: firstNameCtrl, label: 'First Name', enabled: editing,
                            validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                        _Field(ctrl: lastNameCtrl, label: 'Last Name', enabled: editing,
                            validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                      ]),
                      const SizedBox(height: 12),
                      _row([
                        _Field(ctrl: emailCtrl, label: 'Email', enabled: editing,
                            keyboardType: TextInputType.emailAddress),
                        _Field(ctrl: phoneCtrl, label: 'Phone', enabled: editing,
                            keyboardType: TextInputType.phone),
                      ]),
                      const SizedBox(height: 12),
                      _row([
                        if (editing)
                          _Dropdown<String>(
                            label: 'Gender',
                            value: gender,
                            items: genders,
                            labelFor: (v) => v[0].toUpperCase() + v.substring(1),
                            onChanged: onGenderChanged,
                          )
                        else
                          _ReadOnly(label: 'Gender', value: gender != null
                              ? (gender![0].toUpperCase() + gender!.substring(1)) : '—'),
                        _Field(ctrl: idNumberCtrl, label: 'National ID', enabled: editing),
                      ]),
                      const SizedBox(height: 12),
                      _row([
                        if (editing)
                          _Dropdown<String>(
                            label: 'Blood Group',
                            value: bloodGroup,
                            items: bloodGroups,
                            labelFor: (v) => v,
                            onChanged: onBloodGroupChanged,
                          )
                        else
                          _ReadOnly(label: 'Blood Group', value: bloodGroup ?? '—'),
                        GestureDetector(
                          onTap: editing ? onPickDate : null,
                          child: AbsorbPointer(
                            child: _Field(
                              ctrl: TextEditingController(
                                  text: dateOfBirth != null
                                      ? '${dateOfBirth!.year}-${dateOfBirth!.month.toString().padLeft(2, '0')}-${dateOfBirth!.day.toString().padLeft(2, '0')}'
                                      : ''),
                              label: 'Date of Birth',
                              enabled: editing,
                              suffixIcon: editing
                                  ? const Icon(Icons.calendar_today_outlined, size: 16)
                                  : null,
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      _Field(ctrl: addressCtrl, label: 'Address', enabled: editing, maxLines: 2),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _Section(
                    title: 'Medical Information',
                    icon: Icons.medical_information_outlined,
                    accentColor: const Color(0xFFDC2626),
                    children: [
                      _MultiSelectField(
                        label: 'Allergies',
                        selected: selectedAllergies,
                        options: allergyCatalog.map((a) => a.name).toList(),
                        enabled: editing,
                        accentColor: const Color(0xFFDC2626),
                        onChanged: onAllergiesChanged,
                      ),
                      const SizedBox(height: 12),
                      _MultiSelectField(
                        label: 'Chronic Conditions',
                        selected: selectedConditions,
                        options: conditionCatalog.map((c) => c.name).toList(),
                        enabled: editing,
                        accentColor: const Color(0xFFDC2626),
                        onChanged: onConditionsChanged,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _Section(
                    title: 'Emergency Contact',
                    icon: Icons.emergency_outlined,
                    accentColor: const Color(0xFFEA580C),
                    children: [
                      _row([
                        _Field(ctrl: emergencyNameCtrl, label: 'Contact Name', enabled: editing),
                        _Field(ctrl: emergencyPhoneCtrl, label: 'Contact Phone', enabled: editing,
                            keyboardType: TextInputType.phone),
                      ]),
                      const SizedBox(height: 12),
                      _Field(ctrl: emergencyRelationCtrl, label: 'Relationship', enabled: editing),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _Section(
                    title: 'Insurance',
                    icon: Icons.health_and_safety_outlined,
                    accentColor: const Color(0xFF7C3AED),
                    children: [
                      _row([
                        _Field(ctrl: insuranceProviderCtrl, label: 'Insurance Provider', enabled: editing),
                        _Field(ctrl: insurancePolicyCtrl, label: 'Policy Number', enabled: editing),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (editing) _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_circle, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Manage your personal and medical details',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!editing)
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
              label: const Text('Edit',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.15),
            child: Text(
              patient.firstName.isNotEmpty ? patient.firstName[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Color(0xFF0D9488), fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.fullName,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  patient.email ?? '',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          if (patient.bloodGroup != null && patient.bloodGroup!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
              ),
              child: Text(
                patient.bloodGroup!,
                style: const TextStyle(
                    color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: saving ? null : onCancel,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: saving ? null : onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: saving
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _row(List<Widget> children) => Row(
        children: children
            .expand((w) => [Expanded(child: w), const SizedBox(width: 12)])
            .toList()
          ..removeLast(),
      );
}

// ── Section widget ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.border.withValues(alpha: 0.5),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, color: accentColor, size: 16),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Field helpers ─────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool enabled;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.enabled,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        filled: true,
        fillColor: enabled ? AppColors.background : AppColors.background.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0D9488)),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class _ReadOnly extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnly({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.background.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Text(value, style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) labelFor;
  final ValueChanged<T?> onChanged;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.labelFor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0D9488)),
        ),
      ),
      items: items
          .map((v) => DropdownMenuItem<T>(
                value: v,
                child: Text(labelFor(v), style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

// ── Multi-select field ────────────────────────────────────────────────────────

class _MultiSelectField extends StatelessWidget {
  final String label;
  final Set<String> selected;
  final List<String> options;
  final bool enabled;
  final Color accentColor;
  final ValueChanged<Set<String>> onChanged;

  const _MultiSelectField({
    required this.label,
    required this.selected,
    required this.options,
    required this.enabled,
    required this.accentColor,
    required this.onChanged,
  });

  Future<void> _openDialog(BuildContext context) async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _MultiSelectDialog(
        title: label,
        options: options,
        selected: Set.from(selected),
        accentColor: accentColor,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: enabled ? () => _openDialog(context) : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: enabled
                  ? AppColors.background
                  : AppColors.background.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: enabled
                    ? AppColors.border
                    : AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                      ),
                      if (selected.isEmpty)
                        Text(
                          enabled ? 'Tap to select...' : 'None',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary.withValues(alpha: 0.6)),
                        )
                      else
                        const SizedBox(height: 4),
                    ],
                  ),
                ),
                if (enabled)
                  Icon(Icons.arrow_drop_down,
                      color: AppColors.textSecondary, size: 20),
              ],
            ),
          ),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selected.map((item) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item,
                        style: TextStyle(
                            fontSize: 12,
                            color: accentColor,
                            fontWeight: FontWeight.w500)),
                    if (enabled) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          final updated = Set<String>.from(selected)
                            ..remove(item);
                          onChanged(updated);
                        },
                        child: Icon(Icons.close,
                            size: 14, color: accentColor),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _MultiSelectDialog extends StatefulWidget {
  final String title;
  final List<String> options;
  final Set<String> selected;
  final Color accentColor;

  const _MultiSelectDialog({
    required this.title,
    required this.options,
    required this.selected,
    required this.accentColor,
  });

  @override
  State<_MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<_MultiSelectDialog> {
  late Set<String> _current;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _current = Set.from(widget.selected);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.options
        .where((o) => o.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: EdgeInsets.zero,
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        decoration: BoxDecoration(
          color: widget.accentColor.withValues(alpha: 0.08),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(
              bottom:
                  BorderSide(color: widget.accentColor.withValues(alpha: 0.2))),
        ),
        child: Row(
          children: [
            Icon(Icons.checklist_rounded,
                color: widget.accentColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Select ${widget.title}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700))),
            IconButton(
              icon: const Icon(Icons.close, size: 17),
              onPressed: () => Navigator.pop(context),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  prefixIcon: const Icon(Icons.search, size: 16),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: widget.accentColor)),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text('No options found',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final opt = filtered[i];
                        final checked = _current.contains(opt);
                        return CheckboxListTile(
                          dense: true,
                          value: checked,
                          activeColor: widget.accentColor,
                          title: Text(opt,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary)),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _current.add(opt);
                              } else {
                                _current.remove(opt);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _current),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.accentColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(fontSize: 12, color: AppColors.error))),
        ],
      ),
    );
  }
}
