import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../repository/patient_repository.dart';

class PatientFormScreen extends ConsumerStatefulWidget {
  final String? patientId;
  const PatientFormScreen({super.key, this.patientId});

  @override
  ConsumerState<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends ConsumerState<PatientFormScreen> {
  final _repo = PatientRepository();
  final _formKey = GlobalKey<FormState>();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _chronicConditionsCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();
  final _insuranceProviderCtrl = TextEditingController();
  final _insurancePolicyCtrl = TextEditingController();

  String? _gender;
  String? _bloodGroup;
  DateTime? _dateOfBirth;
  bool _loading = false;
  bool _initialLoading = false;

  bool get _isEditing => widget.patientId != null;

  static const _genders = ['male', 'female', 'other'];
  static const _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadPatient();
  }

  Future<void> _loadPatient() async {
    setState(() => _initialLoading = true);
    try {
      final p = await _repo.getPatient(int.parse(widget.patientId!));
      _firstNameCtrl.text = p.firstName;
      _lastNameCtrl.text = p.lastName;
      _emailCtrl.text = p.email ?? '';
      _phoneCtrl.text = p.phone ?? '';
      _idNumberCtrl.text = p.idNumber ?? '';
      _addressCtrl.text = p.address ?? '';
      _allergiesCtrl.text = p.allergies ?? '';
      _chronicConditionsCtrl.text = p.chronicConditions ?? '';
      _emergencyNameCtrl.text = p.emergencyContactName ?? '';
      _emergencyPhoneCtrl.text = p.emergencyContactPhone ?? '';
      _insuranceProviderCtrl.text = p.insuranceProvider ?? '';
      _insurancePolicyCtrl.text = p.insurancePolicyNumber ?? '';
      _gender = p.gender;
      _bloodGroup = p.bloodGroup;
      if (p.dateOfBirth != null) {
        _dateOfBirth = DateTime.tryParse(p.dateOfBirth!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load patient: $e')),
        );
      }
    }
    if (mounted) setState(() => _initialLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final data = {
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'gender': _gender,
      'date_of_birth': _dateOfBirth?.toIso8601String().split('T').first,
      'national_id': _idNumberCtrl.text.trim(),
      'blood_type': _bloodGroup,
      'address': _addressCtrl.text.trim(),
      'allergies': _allergiesCtrl.text.trim().isEmpty
          ? <String>[]
          : _allergiesCtrl.text.trim().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'chronic_conditions': _chronicConditionsCtrl.text.trim().isEmpty
          ? <String>[]
          : _chronicConditionsCtrl.text.trim().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      'emergency_contact_name': _emergencyNameCtrl.text.trim(),
      'emergency_contact_phone': _emergencyPhoneCtrl.text.trim(),
      'insurance_provider': _insuranceProviderCtrl.text.trim(),
      'insurance_number': _insurancePolicyCtrl.text.trim(),
    };

    try {
      if (_isEditing) {
        await _repo.updatePatient(int.parse(widget.patientId!), data);
      } else {
        await _repo.createPatient(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Patient ${_isEditing ? 'updated' : 'registered'} successfully'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
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
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _idNumberCtrl.dispose();
    _addressCtrl.dispose();
    _allergiesCtrl.dispose();
    _chronicConditionsCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _insuranceProviderCtrl.dispose();
    _insurancePolicyCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) return const LoadingWidget();

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header bar ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 4),
                Icon(
                  _isEditing ? Icons.edit_note : Icons.person_add,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit Patient' : 'Register Patient',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loading ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save, size: 18),
                  label: Text(_isEditing ? 'Update' : 'Register'),
                ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Personal Information
                  _FormSection(
                    icon: Icons.person,
                    title: 'Personal Information',
                    color: AppColors.primary,
                    child: LayoutBuilder(builder: (ctx, bc) {
                      final cols = bc.maxWidth > 600 ? 2 : 1;
                      return _grid(cols, [
                        _field('First Name', _firstNameCtrl, required: true),
                        _field('Last Name', _lastNameCtrl, required: true),
                        _field('Email', _emailCtrl,
                            keyboardType: TextInputType.emailAddress),
                        _field('Phone', _phoneCtrl,
                            keyboardType: TextInputType.phone),
                        _field('National ID', _idNumberCtrl),
                        _dropdownField(
                          'Gender',
                          _gender,
                          _genders
                              .map((g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(
                                        g[0].toUpperCase() + g.substring(1)),
                                  ))
                              .toList(),
                          (v) => setState(() => _gender = v),
                        ),
                        _dropdownField(
                          'Blood Group',
                          _bloodGroup,
                          _bloodGroups
                              .map((b) => DropdownMenuItem(
                                    value: b,
                                    child: Text(b),
                                  ))
                              .toList(),
                          (v) => setState(() => _bloodGroup = v),
                        ),
                        _dateField(),
                      ]);
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Address
                  _FormSection(
                    icon: Icons.location_on,
                    title: 'Address',
                    color: AppColors.secondary,
                    child: TextFormField(
                      controller: _addressCtrl,
                      maxLines: 3,
                      decoration: _dec('Address', Icons.home_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Medical Information
                  _FormSection(
                    icon: Icons.medical_information,
                    title: 'Medical Information',
                    color: const Color(0xFFEF4444),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _allergiesCtrl,
                          maxLines: 2,
                          decoration: _dec('Allergies (comma-separated)',
                              Icons.warning_amber_outlined),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _chronicConditionsCtrl,
                          maxLines: 2,
                          decoration: _dec('Chronic Conditions',
                              Icons.monitor_heart_outlined),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Emergency Contact
                  _FormSection(
                    icon: Icons.emergency,
                    title: 'Emergency Contact',
                    color: const Color(0xFFF59E0B),
                    child: LayoutBuilder(builder: (ctx, bc) {
                      final cols = bc.maxWidth > 600 ? 2 : 1;
                      return _grid(cols, [
                        _field('Contact Name', _emergencyNameCtrl),
                        _field('Contact Phone', _emergencyPhoneCtrl,
                            keyboardType: TextInputType.phone),
                      ]);
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Insurance
                  _FormSection(
                    icon: Icons.shield,
                    title: 'Insurance Information',
                    color: const Color(0xFF22C55E),
                    child: LayoutBuilder(builder: (ctx, bc) {
                      final cols = bc.maxWidth > 600 ? 2 : 1;
                      return _grid(cols, [
                        _field('Insurance Provider', _insuranceProviderCtrl),
                        _field('Policy Number', _insurancePolicyCtrl),
                      ]);
                    }),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds an even-column grid from a list of widgets.
  Widget _grid(int cols, List<Widget> children) {
    if (cols == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children
            .expand((w) => [w, const SizedBox(height: 16)])
            .toList()
          ..removeLast(),
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += cols) {
      final rowChildren = children.sublist(
          i, (i + cols) > children.length ? children.length : i + cols);
      if (rowChildren.length < cols) {
        rowChildren.add(const SizedBox.shrink());
      }
      rows.add(Row(
        children: rowChildren
            .expand((w) => [Expanded(child: w), const SizedBox(width: 16)])
            .toList()
          ..removeLast(),
      ));
      if (i + cols < children.length) rows.add(const SizedBox(height: 16));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
      );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool required = false,
    TextInputType? keyboardType,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: _dec(label, Icons.edit_outlined),
        validator: required
            ? (v) =>
                v == null || v.trim().isEmpty ? '$label is required' : null
            : null,
      );

  Widget _dropdownField(
    String label,
    String? value,
    List<DropdownMenuItem<String>> items,
    ValueChanged<String?> onChanged,
  ) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        decoration: _dec(label, Icons.arrow_drop_down_circle_outlined),
        items: items,
        onChanged: onChanged,
      );

  Widget _dateField() => TextFormField(
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'Date of Birth',
          prefixIcon: const Icon(Icons.calendar_today,
              size: 18, color: Color(0xFF64748B)),
          suffixIcon: _dateOfBirth != null
              ? IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() => _dateOfBirth = null),
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.border),
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
        ),
        controller: TextEditingController(
          text: _dateOfBirth != null ? _fmt(_dateOfBirth!) : '',
        ),
        onTap: _pickDate,
      );
}

// ── Section card widget ────────────────────────────────────────────────────────
class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coloured header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ],
      ),
    );
  }
}
