import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import 'providers.dart';

class HomecarePatientEnrollScreen extends ConsumerStatefulWidget {
  const HomecarePatientEnrollScreen({super.key});

  @override
  ConsumerState<HomecarePatientEnrollScreen> createState() => _HomecarePatientEnrollScreenState();
}

class _HomecarePatientEnrollScreenState extends ConsumerState<HomecarePatientEnrollScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _nationalityController = TextEditingController(text: 'KE');
  final _diagnosisController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _historyController = TextEditingController();
  final _manualDoctorNameController = TextEditingController();
  final _manualDoctorSpecializationController = TextEditingController();
  final _manualDoctorPhoneController = TextEditingController();
  final _manualDoctorEmailController = TextEditingController();
  final _manualDoctorHospitalController = TextEditingController();
  final _manualDoctorNotesController = TextEditingController();

  final List<_EmergencyContactDraft> _contacts = [_EmergencyContactDraft(isPrimary: true)];
  final Set<int> _additionalCaregiverIds = <int>{};

  DateTime? _dateOfBirth;
  String _gender = 'female';
  String _idType = 'national_id';
  String _riskLevel = 'low';
  String _doctorMode = 'directory';
  int _currentStep = 0;
  int? _assignedCaregiverId;
  int? _assignedDoctorUserId;
  bool _saving = false;
  String? _topError;
  Map<String, List<String>> _fieldErrors = const {};

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    _idNumberController.dispose();
    _nationalityController.dispose();
    _diagnosisController.dispose();
    _allergiesController.dispose();
    _historyController.dispose();
    _manualDoctorNameController.dispose();
    _manualDoctorSpecializationController.dispose();
    _manualDoctorPhoneController.dispose();
    _manualDoctorEmailController.dispose();
    _manualDoctorHospitalController.dispose();
    _manualDoctorNotesController.dispose();
    for (final contact in _contacts) {
      contact.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 30),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  void _addContact() {
    setState(() {
      _contacts.add(_EmergencyContactDraft(isPrimary: _contacts.isEmpty));
    });
  }

  void _removeContact(int index) {
    if (_contacts.length == 1) return;
    setState(() {
      final removed = _contacts.removeAt(index);
      removed.dispose();
      if (!_contacts.any((contact) => contact.isPrimary)) {
        _contacts.first.isPrimary = true;
      }
    });
  }

  void _markPrimary(int index) {
    setState(() {
      for (var i = 0; i < _contacts.length; i++) {
        _contacts[i].isPrimary = i == index;
      }
    });
  }

  bool _validate() {
    final errors = <String, List<String>>{};

    if (_firstNameController.text.trim().isEmpty) {
      errors['first_name'] = const ['Required'];
    }
    if (_lastNameController.text.trim().isEmpty) {
      errors['last_name'] = const ['Required'];
    }
    if (_emailController.text.trim().isEmpty) {
      errors['user_email'] = const ['Required'];
    }
    if (_idType.trim().isEmpty) {
      errors['id_type'] = const ['Required'];
    }
    if (_idNumberController.text.trim().isEmpty) {
      errors['id_number'] = const ['Required'];
    }

    setState(() {
      _fieldErrors = errors;
      _topError = errors.isEmpty ? null : 'Please fill the required fields first.';
    });
    return errors.isEmpty;
  }

  bool _validateStep(int step) {
    final errors = Map<String, List<String>>.from(_fieldErrors);

    if (step == 0) {
      if (_firstNameController.text.trim().isEmpty) {
        errors['first_name'] = const ['Required'];
      } else {
        errors.remove('first_name');
      }
      if (_lastNameController.text.trim().isEmpty) {
        errors['last_name'] = const ['Required'];
      } else {
        errors.remove('last_name');
      }
      if (_emailController.text.trim().isEmpty) {
        errors['user_email'] = const ['Required'];
      } else {
        errors.remove('user_email');
      }
    }

    if (step == 1) {
      if (_idType.trim().isEmpty) {
        errors['id_type'] = const ['Required'];
      } else {
        errors.remove('id_type');
      }
      if (_idNumberController.text.trim().isEmpty) {
        errors['id_number'] = const ['Required'];
      } else {
        errors.remove('id_number');
      }
    }

    final valid = step == 2 || step == 3 ||
        (step == 0 && !errors.containsKey('first_name') && !errors.containsKey('last_name') && !errors.containsKey('user_email')) ||
        (step == 1 && !errors.containsKey('id_type') && !errors.containsKey('id_number'));

    setState(() {
      _fieldErrors = errors;
      _topError = valid ? null : 'Please complete the required fields in this step.';
    });

    return valid;
  }

  void _handleStepContinue() {
    if (_currentStep == 3) {
      _submit();
      return;
    }
    if (!_validateStep(_currentStep)) return;
    setState(() {
      _currentStep += 1;
    });
  }

  void _handleStepCancel() {
    if (_currentStep == 0) {
      context.pop();
      return;
    }
    setState(() {
      _currentStep -= 1;
    });
  }

  void _handleStepTapped(int step) {
    if (step <= _currentStep || _validateStep(_currentStep)) {
      setState(() {
        _currentStep = step;
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_saving || !_validate()) return;

    setState(() {
      _saving = true;
      _topError = null;
    });

    final payload = <String, dynamic>{
      'user_email': _emailController.text.trim(),
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'password': _passwordController.text,
      'date_of_birth': _dateOfBirth == null ? null : _formatDate(_dateOfBirth!),
      'gender': _gender,
      'address': _addressController.text.trim(),
      'id_type': _idType,
      'id_number': _idNumberController.text.trim(),
      'nationality': _nationalityController.text.trim().isEmpty ? 'KE' : _nationalityController.text.trim(),
      'primary_diagnosis': _diagnosisController.text.trim(),
      'medical_history': _historyController.text.trim(),
      'allergies': _allergiesController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .join(', '),
      'risk_level': _riskLevel,
      'assigned_doctor_user_id': _doctorMode == 'directory' ? _assignedDoctorUserId : null,
      'assigned_doctor_info': _doctorMode == 'manual' && _manualDoctorNameController.text.trim().isNotEmpty
          ? {
              'name': _manualDoctorNameController.text.trim(),
              'specialization': _manualDoctorSpecializationController.text.trim(),
              'phone': _manualDoctorPhoneController.text.trim(),
              'email': _manualDoctorEmailController.text.trim(),
              'hospital': _manualDoctorHospitalController.text.trim(),
              'notes': _manualDoctorNotesController.text.trim(),
            }
          : null,
      'assigned_caregiver': _assignedCaregiverId,
      'additional_caregivers': _additionalCaregiverIds.toList(),
      'emergency_contacts': _contacts
          .where((contact) => contact.name.text.trim().isNotEmpty && contact.phone.text.trim().isNotEmpty)
          .map((contact) => {
                'name': contact.name.text.trim(),
                'relationship': contact.relationship.text.trim(),
                'phone': contact.phone.text.trim(),
                'email': contact.email.text.trim(),
                'address': contact.address.text.trim(),
                'is_primary': contact.isPrimary,
              })
          .toList(),
    };
    if (payload['date_of_birth'] == null) {
      payload.remove('date_of_birth');
    }

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/homecare/patients/enroll/', data: payload);
      ref.invalidate(homecarePatientsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient enrolled successfully')),
      );
      final id = res.data['id'];
      context.go('/homecare/patients/$id');
    } on DioException catch (error) {
      final response = error.response?.data;
      final parsed = _parseFieldErrors(response);
      if (!mounted) return;
      setState(() {
        _fieldErrors = parsed;
        _topError = _extractErrorMessage(response) ?? 'Enrolment failed.';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final caregiversAsync = ref.watch(homecareEnrollmentCaregiversProvider);
    final doctorsAsync = ref.watch(homecareDoctorDirectoryProvider);

    final caregivers = caregiversAsync.valueOrNull?.cast<dynamic>() ?? const [];
    final doctors = doctorsAsync.valueOrNull?.cast<dynamic>() ?? const [];

    final selectedDoctor = doctors.cast<Map>().cast<Map<String, dynamic>?>().firstWhere(
          (doctor) => doctor?['user'] == _assignedDoctorUserId,
          orElse: () => null,
        );

    final additionalCaregiverChoices = caregivers
        .where((caregiver) => caregiver['id'] != _assignedCaregiverId)
        .cast<dynamic>()
        .toList();

    final steps = <Step>[
      Step(
        title: const Text('Identity'),
        subtitle: const Text('Patient details'),
        isActive: _currentStep >= 0,
        state: _stepState(0),
        content: _SectionCard(
          title: 'Patient identity',
          subtitle: 'Required registration details used by the homecare web flow.',
          icon: Icons.badge_rounded,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _AppTextField(
                      controller: _firstNameController,
                      label: 'First name',
                      errorText: _errorFor('first_name'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AppTextField(
                      controller: _lastNameController,
                      label: 'Last name',
                      errorText: _errorFor('last_name'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _AppTextField(
                controller: _emailController,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                errorText: _errorFor('user_email'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _AppTextField(
                      controller: _phoneController,
                      label: 'Phone',
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AppTextField(
                      controller: _passwordController,
                      label: 'Password',
                      obscureText: true,
                      helperText: 'Optional patient login password',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _DropdownField<String>(
                      label: 'Gender',
                      value: _gender,
                      items: const [
                        DropdownMenuItem(value: 'female', child: Text('Female')),
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (value) => setState(() => _gender = value ?? 'female'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'Date of birth',
                      value: _dateOfBirth == null ? 'Select date' : _formatDate(_dateOfBirth!),
                      onTap: _pickDateOfBirth,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Clinical'),
        subtitle: const Text('Medical profile'),
        isActive: _currentStep >= 1,
        state: _stepState(1),
        content: _SectionCard(
          title: 'Clinical profile',
          subtitle: 'Capture the same baseline details used on the Nuxt enrolment page.',
          icon: Icons.medical_information_rounded,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _DropdownField<String>(
                      label: 'ID type',
                      value: _idType,
                      errorText: _errorFor('id_type'),
                      items: const [
                        DropdownMenuItem(value: 'national_id', child: Text('National ID')),
                        DropdownMenuItem(value: 'passport', child: Text('Passport')),
                        DropdownMenuItem(value: 'alien_id', child: Text('Alien ID')),
                        DropdownMenuItem(value: 'birth_certificate', child: Text('Birth certificate')),
                      ],
                      onChanged: (value) => setState(() => _idType = value ?? 'national_id'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AppTextField(
                      controller: _idNumberController,
                      label: 'ID number',
                      errorText: _errorFor('id_number'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _AppTextField(
                      controller: _nationalityController,
                      label: 'Nationality',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DropdownField<String>(
                      label: 'Risk level',
                      value: _riskLevel,
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(value: 'critical', child: Text('Critical')),
                      ],
                      onChanged: (value) => setState(() => _riskLevel = value ?? 'low'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _AppTextField(
                controller: _diagnosisController,
                label: 'Primary diagnosis',
              ),
              const SizedBox(height: 12),
              _AppTextField(
                controller: _allergiesController,
                label: 'Allergies',
                helperText: 'Separate multiple items with commas',
              ),
              const SizedBox(height: 12),
              _AppTextField(
                controller: _historyController,
                label: 'Medical history',
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              _AppTextField(
                controller: _addressController,
                label: 'Address',
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Care Team'),
        subtitle: const Text('Assignments'),
        isActive: _currentStep >= 2,
        state: _stepState(2),
        content: _SectionCard(
          title: 'Care team',
          subtitle: 'Assign caregiver coverage and responsible doctor.',
          icon: Icons.groups_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DropdownField<int?>(
                label: 'Primary caregiver',
                value: _assignedCaregiverId,
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Unassigned')),
                  ...caregivers.map((caregiver) => DropdownMenuItem<int?>(
                        value: caregiver['id'] as int?,
                        child: Text(_caregiverName(caregiver)),
                      )),
                ],
                onChanged: (value) {
                  setState(() {
                    _assignedCaregiverId = value;
                    _additionalCaregiverIds.remove(value);
                  });
                },
              ),
              if (additionalCaregiverChoices.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Additional caregivers', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final caregiver in additionalCaregiverChoices)
                      FilterChip(
                        selected: _additionalCaregiverIds.contains(caregiver['id']),
                        onSelected: (selected) {
                          setState(() {
                            final id = caregiver['id'] as int?;
                            if (id == null) return;
                            if (selected) {
                              _additionalCaregiverIds.add(id);
                            } else {
                              _additionalCaregiverIds.remove(id);
                            }
                          });
                        },
                        label: Text(_caregiverName(caregiver)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'directory', label: Text('Doctor directory'), icon: Icon(Icons.local_hospital_rounded)),
                  ButtonSegment(value: 'manual', label: Text('Enter manually'), icon: Icon(Icons.edit_note_rounded)),
                ],
                selected: {_doctorMode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _doctorMode = selection.first;
                    if (_doctorMode == 'directory') {
                      _clearManualDoctor();
                    } else {
                      _assignedDoctorUserId = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              if (_doctorMode == 'directory') ...[
                _DropdownField<int?>(
                  label: 'Responsible doctor',
                  value: _assignedDoctorUserId,
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Not assigned')),
                    ...doctors.map((doctor) => DropdownMenuItem<int?>(
                          value: doctor['user'] as int?,
                          child: Text(_doctorName(doctor)),
                        )),
                  ],
                  onChanged: (value) => setState(() => _assignedDoctorUserId = value),
                ),
                if (selectedDoctor != null) ...[
                  const SizedBox(height: 12),
                  _DetailCard(
                    icon: Icons.local_hospital_rounded,
                    title: _doctorName(selectedDoctor),
                    subtitle: [
                      if ((selectedDoctor['specialization'] ?? '').toString().isNotEmpty)
                        selectedDoctor['specialization'].toString(),
                      if ((selectedDoctor['email'] ?? '').toString().isNotEmpty)
                        selectedDoctor['email'].toString(),
                      if ((selectedDoctor['phone'] ?? '').toString().isNotEmpty)
                        selectedDoctor['phone'].toString(),
                    ].join(' • '),
                  ),
                ],
              ] else ...[
                _AppTextField(controller: _manualDoctorNameController, label: 'Doctor full name'),
                const SizedBox(height: 12),
                _AppTextField(controller: _manualDoctorSpecializationController, label: 'Specialization'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _AppTextField(
                        controller: _manualDoctorPhoneController,
                        label: 'Doctor phone',
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AppTextField(
                        controller: _manualDoctorEmailController,
                        label: 'Doctor email',
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _AppTextField(controller: _manualDoctorHospitalController, label: 'Hospital or clinic'),
                const SizedBox(height: 12),
                _AppTextField(controller: _manualDoctorNotesController, label: 'Doctor notes', maxLines: 3),
              ],
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Contacts'),
        subtitle: const Text('Emergency'),
        isActive: _currentStep >= 3,
        state: _stepState(3),
        content: _SectionCard(
          title: 'Emergency contacts',
          subtitle: 'At least one complete contact is recommended for active care.',
          icon: Icons.contact_emergency_rounded,
          trailing: TextButton.icon(
            onPressed: _addContact,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add'),
          ),
          child: Column(
            children: [
              for (var index = 0; index < _contacts.length; index++) ...[
                _EmergencyContactCard(
                  index: index,
                  draft: _contacts[index],
                  onRemove: _contacts.length == 1 ? null : () => _removeContact(index),
                  onMarkPrimary: () => _markPrimary(index),
                ),
                if (index != _contacts.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        title: const Text('Enrol Patient', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D9488), Color(0xFF0284C7)],
              ),
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create a patient record and assign the care team from mobile.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Step ${_currentStep + 1} of ${steps.length}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: (_currentStep + 1) / steps.length,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (caregiversAsync.isLoading || doctorsAsync.isLoading)
            const LinearProgressIndicator(minHeight: 3),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
              children: [
                if (caregiversAsync.hasError || doctorsAsync.hasError)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
                    child: _InlineWarning(
                      message: 'Some directory options failed to load. You can still complete the enrolment manually.',
                    ),
                  ),
                if (_topError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    child: _InlineWarning(message: _topError!),
                  ),
                Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: cs.copyWith(primary: const Color(0xFF0D9488)),
                  ),
                  child: Stepper(
                    currentStep: _currentStep,
                    type: StepperType.vertical,
                    physics: const ClampingScrollPhysics(),
                    onStepTapped: _handleStepTapped,
                    onStepContinue: _saving ? null : _handleStepContinue,
                    onStepCancel: _saving ? null : _handleStepCancel,
                    controlsBuilder: (context, details) {
                      final isLastStep = _currentStep == steps.length - 1;
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            FilledButton.icon(
                              onPressed: _saving ? null : details.onStepContinue,
                              icon: _saving && isLastStep
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Icon(isLastStep ? Icons.check_circle_rounded : Icons.arrow_forward_rounded),
                              label: Text(
                                _saving && isLastStep
                                    ? 'Enrolling...'
                                    : isLastStep
                                        ? 'Enrol patient'
                                        : 'Continue',
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: _saving ? null : details.onStepCancel,
                              child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
                            ),
                          ],
                        ),
                      );
                    },
                    steps: steps,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _clearManualDoctor() {
    _manualDoctorNameController.clear();
    _manualDoctorSpecializationController.clear();
    _manualDoctorPhoneController.clear();
    _manualDoctorEmailController.clear();
    _manualDoctorHospitalController.clear();
    _manualDoctorNotesController.clear();
  }

  String? _errorFor(String key) {
    final values = _fieldErrors[key];
    if (values == null || values.isEmpty) return null;
    return values.join(' ');
  }

  StepState _stepState(int step) {
    if (_currentStep > step) return StepState.complete;
    if (_currentStep == step) return StepState.editing;
    return StepState.indexed;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: const Color(0xFF0D9488)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: Color(0xFF92400E)))),
        ],
      ),
    );
  }
}

class _AppTextField extends StatelessWidget {
  const _AppTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
    this.obscureText = false,
    this.errorText,
    this.helperText,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool obscureText;
  final String? errorText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        errorText: errorText,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.errorText,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
        child: Row(
          children: [
            Expanded(child: Text(value)),
            const Icon(Icons.calendar_month_rounded),
          ],
        ),
      ),
    );
  }
}

class _EmergencyContactCard extends StatelessWidget {
  const _EmergencyContactCard({
    required this.index,
    required this.draft,
    required this.onMarkPrimary,
    this.onRemove,
  });

  final int index;
  final _EmergencyContactDraft draft;
  final VoidCallback onMarkPrimary;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Contact ${index + 1}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (draft.isPrimary)
                const Chip(label: Text('Primary')),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          _AppTextField(controller: draft.name, label: 'Full name'),
          const SizedBox(height: 12),
          _AppTextField(controller: draft.relationship, label: 'Relationship'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AppTextField(
                  controller: draft.phone,
                  label: 'Phone',
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AppTextField(
                  controller: draft.email,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AppTextField(controller: draft.address, label: 'Address', maxLines: 2),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onMarkPrimary,
              icon: Icon(draft.isPrimary ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded),
              label: Text(draft.isPrimary ? 'Primary contact' : 'Mark primary'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.14),
            child: Icon(icon, color: const Color(0xFF0D9488)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyContactDraft {
  _EmergencyContactDraft({this.isPrimary = false});

  final name = TextEditingController();
  final relationship = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final address = TextEditingController();
  bool isPrimary;

  void dispose() {
    name.dispose();
    relationship.dispose();
    phone.dispose();
    email.dispose();
    address.dispose();
  }
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _caregiverName(dynamic caregiver) {
  final user = caregiver['user'] as Map<String, dynamic>? ?? const {};
  final fullName = (user['full_name'] ?? '').toString().trim();
  if (fullName.isNotEmpty) return fullName;
  final joined = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
  if (joined.isNotEmpty) return joined;
  return caregiver['email']?.toString() ?? 'Caregiver #${caregiver['id']}';
}

String _doctorName(dynamic doctor) {
  final name = (doctor['name'] ?? '').toString().trim();
  if (name.isNotEmpty) return name;
  return doctor['email']?.toString() ?? 'Doctor #${doctor['id']}';
}

Map<String, List<String>> _parseFieldErrors(dynamic data) {
  if (data is! Map) return const {};
  final parsed = <String, List<String>>{};
  data.forEach((key, value) {
    if (key == 'detail') return;
    if (value is List) {
      parsed[key.toString()] = value.map((item) => item.toString()).toList();
    } else if (value != null) {
      parsed[key.toString()] = [value.toString()];
    }
  });
  return parsed;
}

String? _extractErrorMessage(dynamic data) {
  if (data is Map && data['detail'] != null) {
    return data['detail'].toString();
  }
  if (data is String && data.trim().isNotEmpty) {
    return data;
  }
  return null;
}