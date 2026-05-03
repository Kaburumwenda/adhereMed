import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../core/theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/loading_widget.dart';

class StaffFormScreen extends ConsumerStatefulWidget {
  final int? staffId;
  const StaffFormScreen({super.key, this.staffId});

  @override
  ConsumerState<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends ConsumerState<StaffFormScreen> {
  final Dio _dio = ApiClient.instance;
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _initialLoading = false;
  String? _error;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _qualificationCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  String _role = 'pharmacist';
  int? _specialization;
  bool _isAvailable = true;

  /// Loaded from API: [{id, name}, ...]
  List<Map<String, dynamic>> _specializationChoices = [];

  bool get _isEditing => widget.staffId != null;

  static const _roles = {
    'pharmacist': 'Pharmacist',
    'pharmacy_tech': 'Pharmacy Technician',
    'cashier': 'Cashier',
  };

  @override
  void initState() {
    super.initState();
    _loadChoices();
    if (_isEditing) _loadStaff();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _licenseCtrl.dispose();
    _qualificationCtrl.dispose();
    _experienceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChoices() async {
    try {
      final response = await _dio.get('/staff/specializations/');
      final list = response.data['results'] as List<dynamic>? ??
          (response.data is List ? response.data as List : []);
      setState(() {
        _specializationChoices = list
            .map((e) => {
                  'id': e['id'] as int,
                  'name': (e['name'] as String?) ?? '',
                })
            .toList();
      });
    } catch (_) {
      // silently fallback – dropdown will be empty
    }
  }

  Future<void> _loadStaff() async {
    setState(() => _initialLoading = true);
    try {
      final response = await _dio.get('/staff/${widget.staffId}/');
      final data = response.data as Map<String, dynamic>;
      final nameParts = (data['user_name'] as String? ?? '').split(' ');
      _firstNameCtrl.text = nameParts.isNotEmpty ? nameParts.first : '';
      _lastNameCtrl.text = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      _emailCtrl.text = data['user_email'] as String? ?? '';
      _phoneCtrl.text = data['user_phone'] as String? ?? '';
      _role = data['user_role'] as String? ?? 'pharmacist';
      _specialization = data['specialization'] as int?;
      _licenseCtrl.text = data['license_number'] as String? ?? '';
      _qualificationCtrl.text = data['qualification'] as String? ?? '';
      _experienceCtrl.text = '${data['years_of_experience'] ?? 0}';
      _isAvailable = data['is_available'] as bool? ?? true;
      setState(() => _initialLoading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _initialLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isEditing) {
        await _dio.patch('/staff/${widget.staffId}/', data: {
          'first_name': _firstNameCtrl.text.trim(),
          'last_name': _lastNameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'role': _role,
          'specialization': _specialization,
          'license_number': _licenseCtrl.text.trim(),
          'qualification': _qualificationCtrl.text.trim(),
          'years_of_experience': int.tryParse(_experienceCtrl.text.trim()) ?? 0,
          'is_available': _isAvailable,
        });
      } else {
        await _dio.post('/staff/', data: {
          'email': _emailCtrl.text.trim(),
          'first_name': _firstNameCtrl.text.trim(),
          'last_name': _lastNameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'role': _role,
          'password': _passwordCtrl.text,
          'specialization': _specialization,
          'license_number': _licenseCtrl.text.trim(),
          'qualification': _qualificationCtrl.text.trim(),
          'years_of_experience': int.tryParse(_experienceCtrl.text.trim()) ?? 0,
          'is_available': _isAvailable,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Staff member ${_isEditing ? 'updated' : 'added'} successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(true);
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      String msg;
      if (data is Map) {
        msg = data.values
            .map((v) => v is List ? v.join(', ') : '$v')
            .join('\n');
      } else {
        msg = e.message ?? 'Something went wrong';
      }
      setState(() {
        _error = msg;
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
    if (_initialLoading) return const Center(child: LoadingWidget());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Text(
                _isEditing ? 'Edit Staff Member' : 'Add Staff Member',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_error!,
                              style: TextStyle(color: AppColors.error)),
                        ),

                      // ── Account Info ──
                      Text('Account Information',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'First Name *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _lastNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Last Name *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _emailCtrl,
                              enabled: !_isEditing,
                              decoration: const InputDecoration(
                                labelText: 'Email *',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Required';
                                if (!v.contains('@')) return 'Invalid email';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _phoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _role,
                              decoration: const InputDecoration(
                                labelText: 'Role *',
                                border: OutlineInputBorder(),
                              ),
                              items: _roles.entries
                                  .map((e) => DropdownMenuItem(
                                      value: e.key, child: Text(e.value)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _role = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (!_isEditing)
                            Expanded(
                              child: TextFormField(
                                controller: _passwordCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Password *',
                                  border: OutlineInputBorder(),
                                ),
                                obscureText: true,
                                validator: (v) {
                                  if (!_isEditing &&
                                      (v == null || v.length < 8)) {
                                    return 'Min 8 characters';
                                  }
                                  return null;
                                },
                              ),
                            )
                          else
                            const Expanded(child: SizedBox()),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // ── Professional Info ──
                      Text('Professional Information',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _specialization != null &&
                                      _specializationChoices.any(
                                          (c) => c['id'] == _specialization)
                                  ? _specialization
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'Specialization',
                                border: OutlineInputBorder(),
                              ),
                              items: _specializationChoices
                                  .map((c) => DropdownMenuItem<int>(
                                      value: c['id'] as int,
                                      child: Text(c['name'] as String)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _specialization = v),
                              isExpanded: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _qualificationCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Qualification',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _licenseCtrl,
                              decoration: const InputDecoration(
                                labelText: 'License Number',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _experienceCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Years of Experience',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Available'),
                        value: _isAvailable,
                        onChanged: (v) => setState(() => _isAvailable = v),
                        contentPadding: EdgeInsets.zero,
                      ),

                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _loading ? null : _save,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(_isEditing
                                  ? 'Update Staff Member'
                                  : 'Add Staff Member'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
