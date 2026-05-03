import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../repository/doctor_repository.dart';

class DoctorRegisterScreen extends ConsumerStatefulWidget {
  const DoctorRegisterScreen({super.key});

  @override
  ConsumerState<DoctorRegisterScreen> createState() =>
      _DoctorRegisterScreenState();
}

class _DoctorRegisterScreenState extends ConsumerState<DoctorRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = DoctorRepository();

  // User fields
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  // Doctor profile fields
  final _licenseCtrl = TextEditingController();
  final _qualificationCtrl = TextEditingController();
  final _yearsCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _hospitalNameCtrl = TextEditingController();

  String _practiceType = 'independent';
  String? _specialization;
  int? _selectedHospitalId;
  List<Map<String, dynamic>> _hospitals = [];
  bool _enterHospitalManually = false;
  bool _loadingHospitals = false;
  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;

  static const _specializations = [
    'General Medicine',
    'Cardiology',
    'Pediatrics',
    'Orthopedics',
    'Dermatology',
    'Neurology',
    'Psychiatry',
    'Obstetrics & Gynecology',
    'Ophthalmology',
    'ENT (Ear, Nose & Throat)',
    'Urology',
    'Oncology',
    'Radiology',
    'Anesthesiology',
    'General Surgery',
    'Dental',
    'Pulmonology',
    'Nephrology',
    'Gastroenterology',
    'Endocrinology',
    'Rheumatology',
    'Hematology',
    'Infectious Disease',
    'Emergency Medicine',
    'Family Medicine',
    'Pathology',
    'Plastic Surgery',
    'Physiotherapy',
  ];

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _hospitalNameCtrl.dispose();
    _licenseCtrl.dispose();
    _qualificationCtrl.dispose();
    _yearsCtrl.dispose();
    _bioCtrl.dispose();
    _feeCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchHospitals() async {
    setState(() => _loadingHospitals = true);
    try {
      final response = await ApiClient.instance.get('/tenants/hospitals/');
      final results = response.data is List
          ? response.data as List
          : (response.data['results'] as List?) ?? [];
      setState(() {
        _hospitals = results
            .map((e) => {'id': e['id'], 'name': e['name']})
            .toList();
      });
    } catch (_) {
      // Silently fail – user can still enter manually
    }
    if (mounted) setState(() => _loadingHospitals = false);
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final data = <String, dynamic>{
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'practice_type': _practiceType,
        if (_practiceType == 'hospital' && _selectedHospitalId != null)
          'hospital': _selectedHospitalId,
        if (_practiceType == 'hospital' && _enterHospitalManually)
          'hospital_name': _hospitalNameCtrl.text.trim(),
        'specialization': _specialization ?? '',
        'license_number': _licenseCtrl.text.trim(),
        'qualification': _qualificationCtrl.text.trim(),
        'years_of_experience': int.tryParse(_yearsCtrl.text) ?? 0,
        'bio': _bioCtrl.text.trim(),
        'consultation_fee': _feeCtrl.text.trim().isEmpty
            ? '0'
            : _feeCtrl.text.trim(),
      };

      final result = await _repo.register(data);

      // Save tokens and log in
      final tokens = result['tokens'] as Map<String, dynamic>;
      await ApiClient.setTokens(
        access: tokens['access'],
        refresh: tokens['refresh'],
      );
      await ApiClient.saveUser(result['user']);

      if (mounted) {
        // Force auth to reload
        ref.invalidate(authProvider);
        context.go('/dashboard');
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      String message = 'Registration failed. Please try again.';
      if (data is Map) {
        final errors = data.entries
            .map((e) =>
                e.value is List ? (e.value as List).join(', ') : '${e.value}')
            .join('\n');
        if (errors.isNotEmpty) message = errors;
      }
      setState(() => _errorMessage = message);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.medical_services,
                          size: 48, color: AppColors.primary),
                      const SizedBox(height: 8),
                      Text(
                        'Doctor Registration',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Register as a doctor on AdhereMed',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_errorMessage!,
                              style: TextStyle(color: AppColors.error)),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Personal Info ──
                      Text('Personal Information',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'First Name',
                              prefixIcon: Icon(Icons.person_outlined),
                            ),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Last Name'),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (!v.contains('@')) return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone (optional)',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 8) return 'Min 8 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordCtrl,
                        obscureText: _obscurePassword,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_outlined),
                        ),
                        validator: (v) {
                          if (v != _passwordCtrl.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),
                      // ── Professional Info ──
                      Text('Professional Information',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _practiceType,
                        decoration: const InputDecoration(
                          labelText: 'Practice Type',
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'independent',
                              child: Text('Independent Practice')),
                          DropdownMenuItem(
                              value: 'hospital',
                              child: Text('Hospital-Affiliated')),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _practiceType = v ?? 'independent';
                            _selectedHospitalId = null;
                            _enterHospitalManually = false;
                            _hospitalNameCtrl.clear();
                          });
                          if (v == 'hospital' && _hospitals.isEmpty) {
                            _fetchHospitals();
                          }
                        },
                      ),

                      // ── Hospital selection (shown when hospital-affiliated) ──
                      if (_practiceType == 'hospital') ...[
                        const SizedBox(height: 12),
                        if (_loadingHospitals)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                                child: SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))),
                          )
                        else if (!_enterHospitalManually) ...[
                          DropdownButtonFormField<int>(
                            initialValue: _selectedHospitalId,
                            decoration: const InputDecoration(
                              labelText: 'Select Hospital',
                              prefixIcon: Icon(Icons.local_hospital),
                            ),
                            isExpanded: true,
                            items: _hospitals
                                .map((h) => DropdownMenuItem<int>(
                                    value: h['id'] as int,
                                    child: Text(h['name'] as String)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedHospitalId = v),
                            validator: (v) =>
                                v == null ? 'Please select a hospital' : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => setState(
                                  () => _enterHospitalManually = true),
                              icon: const Icon(Icons.edit, size: 16),
                              label:
                                  const Text('Hospital not listed? Enter manually'),
                            ),
                          ),
                        ] else ...[
                          TextFormField(
                            controller: _hospitalNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Hospital Name',
                              prefixIcon: Icon(Icons.local_hospital),
                              hintText: 'Enter hospital name',
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Please enter a hospital name'
                                : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => setState(() {
                                _enterHospitalManually = false;
                                _hospitalNameCtrl.clear();
                              }),
                              icon: const Icon(Icons.list, size: 16),
                              label:
                                  const Text('Select from registered hospitals'),
                            ),
                          ),
                        ],
                      ],

                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _specialization,
                        decoration: const InputDecoration(
                          labelText: 'Specialization',
                          prefixIcon: Icon(Icons.local_hospital_outlined),
                        ),
                        isExpanded: true,
                        items: _specializations
                            .map((s) => DropdownMenuItem(
                                value: s, child: Text(s)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _specialization = v),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _licenseCtrl,
                        decoration: const InputDecoration(
                          labelText: 'License Number',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qualificationCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Qualification',
                              hintText: 'e.g. MBBS, MD',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            controller: _yearsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Years Exp.'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _feeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Consultation Fee',
                          prefixIcon: Icon(Icons.attach_money_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bioCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Bio (optional)',
                          hintText: 'Tell patients about yourself...',
                        ),
                      ),

                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loading ? null : _handleRegister,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Register as Doctor'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Already have an account? ',
                              style:
                                  TextStyle(color: AppColors.textSecondary)),
                          TextButton(
                            onPressed: () => context.go('/login'),
                            child: const Text('Sign In'),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Not a doctor? ',
                              style:
                                  TextStyle(color: AppColors.textSecondary)),
                          TextButton(
                            onPressed: () => context.go('/register'),
                            child: const Text('Patient Registration'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
