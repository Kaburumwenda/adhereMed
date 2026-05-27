import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import 'providers.dart';

class HomecareCaregiverEnrollScreen extends ConsumerStatefulWidget {
  const HomecareCaregiverEnrollScreen({super.key});

  @override
  ConsumerState<HomecareCaregiverEnrollScreen> createState() => _HomecareCaregiverEnrollScreenState();
}

class _HomecareCaregiverEnrollScreenState extends ConsumerState<HomecareCaregiverEnrollScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController(text: 'caregiver1234');
  final _licenseController = TextEditingController();
  final _bioController = TextEditingController();
  final _hourlyRateController = TextEditingController(text: '0');
  final _customSkillsController = TextEditingController();

  String _category = 'nurse';
  DateTime? _hireDate;
  bool _isAvailable = true;
  bool _isIndependent = false;
  bool _saving = false;
  String? _topError;
  final Set<String> _selectedSkills = <String>{};

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _licenseController.dispose();
    _bioController.dispose();
    _hourlyRateController.dispose();
    _customSkillsController.dispose();
    super.dispose();
  }

  Future<void> _pickHireDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _hireDate ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _hireDate = picked);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _topError = null);
    if (!_formKey.currentState!.validate()) return;

    final skills = <String>{
      ..._selectedSkills,
      ..._customSkillsController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
    }.toList()
      ..sort();

    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/homecare/caregivers/enroll/', data: {
        'category': _category,
        'user_email': _emailController.text.trim(),
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text,
        'license_number': _licenseController.text.trim(),
        'specialties': skills,
        'bio': _bioController.text.trim(),
        'hourly_rate': double.tryParse(_hourlyRateController.text.trim()) ?? 0,
        'hire_date': _hireDate == null ? null : _formatDate(_hireDate!),
        'is_available': _isAvailable,
        'is_independent': _isIndependent,
      });
      ref.invalidate(homecareCaregiversProvider);
      if (!mounted) return;
      context.go('/homecare/caregivers/${response.data['id']}');
    } on DioException catch (error) {
      final data = error.response?.data;
      if (!mounted) return;
      setState(() {
        _topError = data is Map && data['detail'] != null
            ? data['detail'].toString()
            : 'Could not create caregiver.';
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
    final categoryOptions = _categoryCards;
    final suggestions = _suggestedSpecialties;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Caregiver')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35))),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.person_add_alt_1_rounded),
                  label: Text(_saving ? 'Enrolling...' : 'Enrol caregiver'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 10, 20, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F766E), Color(0xFF14B8A6), Color(0xFF2DD4BF)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HOMECARE · ENROLMENT',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add caregiver',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Onboard a new nurse or health-care assistant to your homecare team.',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_topError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _InlineError(message: _topError!),
                      ),
                    _SectionCard(
                      title: 'Caregiver category',
                      subtitle: 'Choose the care role before entering profile and employment details.',
                      icon: Icons.badge_rounded,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 720;
                          final cards = categoryOptions.map((option) => _CategoryChoiceCard(
                                option: option,
                                selected: _category == option.value,
                                onTap: () => setState(() => _category = option.value),
                              ));
                          if (compact) {
                            return Column(
                              children: cards
                                  .map((card) => Padding(padding: const EdgeInsets.only(bottom: 12), child: card))
                                  .toList(),
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: cards.first),
                              const SizedBox(width: 12),
                              Expanded(child: cards.last),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Personal information',
                      subtitle: 'Create the caregiver account and contact details used in the field roster.',
                      icon: Icons.person_rounded,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _AppTextField(
                                  controller: _emailController,
                                  label: 'Email',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Email is required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _AppTextField(
                                  controller: _phoneController,
                                  label: 'Phone',
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _AppTextField(
                                  controller: _firstNameController,
                                  label: 'First name',
                                  validator: (value) => (value == null || value.trim().isEmpty) ? 'First name is required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _AppTextField(
                                  controller: _lastNameController,
                                  label: 'Last name',
                                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Last name is required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _AppTextField(
                                  controller: _passwordController,
                                  label: 'Initial password',
                                  helperText: 'Caregiver can change it on first login',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _AppTextField(
                                  controller: _licenseController,
                                  label: _category == 'nurse' ? 'Nursing license' : 'Certification ID',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Professional details',
                      subtitle: 'Capture the same care skills and roster attributes surfaced in the web module.',
                      icon: Icons.local_hospital_rounded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Suggested skills', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: suggestions.map((skill) {
                              final selected = _selectedSkills.contains(skill);
                              return FilterChip(
                                label: Text(skill),
                                selected: selected,
                                onSelected: (value) {
                                  setState(() {
                                    if (value) {
                                      _selectedSkills.add(skill);
                                    } else {
                                      _selectedSkills.remove(skill);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          _AppTextField(
                            controller: _customSkillsController,
                            label: 'Additional skills',
                            helperText: 'Separate custom skills with commas',
                          ),
                          const SizedBox(height: 12),
                          _AppTextField(
                            controller: _bioController,
                            label: 'Short bio',
                            maxLines: 4,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _AppTextField(
                                  controller: _hourlyRateController,
                                  label: 'Hourly rate (KSh)',
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _DateField(
                                  label: 'Hire date',
                                  value: _hireDate == null ? 'Select date' : _formatDate(_hireDate!),
                                  onTap: _pickHireDate,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            value: _isIndependent,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Independent contractor'),
                            subtitle: const Text('Turn on if the caregiver is not a direct employee.'),
                            onChanged: (value) => setState(() => _isIndependent = value),
                          ),
                          SwitchListTile.adaptive(
                            value: _isAvailable,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Available for visits'),
                            subtitle: const Text('Visible as available in roster and assignments screens.'),
                            onChanged: (value) => setState(() => _isAvailable = value),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_CategoryOption> get _categoryCards => const [
        _CategoryOption(
          value: 'nurse',
          title: 'Nurse',
          description: 'Registered nurse for clinical procedures, medication, and wound care.',
          icon: Icons.medical_services_rounded,
          color: Color(0xFF4F46E5),
        ),
        _CategoryOption(
          value: 'hca',
          title: 'Health Care Assistant',
          description: 'Personal care, mobility, companionship, and daily living support.',
          icon: Icons.volunteer_activism_rounded,
          color: Color(0xFFDB2777),
        ),
      ];

  List<String> get _suggestedSpecialties => _category == 'nurse'
      ? const [
          'Wound care',
          'IV therapy',
          'Medication administration',
          'Post-surgical care',
          'Diabetes management',
          'Palliative care',
        ]
      : const [
          'Personal hygiene',
          'Mobility assistance',
          'Companionship',
          'Vital signs monitoring',
          'Dementia care',
          'Meal preparation',
        ];
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.subtitle, required this.icon, required this.child});

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _CategoryChoiceCard extends StatelessWidget {
  const _CategoryChoiceCard({required this.option, required this.selected, required this.onTap});

  final _CategoryOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? option.color.withValues(alpha: 0.08) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? option.color.withValues(alpha: 0.34) : Colors.transparent, width: 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(backgroundColor: option.color, child: Icon(option.icon, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(option.description, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.35)),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle_rounded, color: option.color),
            ],
          ),
        ),
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
    this.helperText,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? helperText;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _CategoryOption {
  const _CategoryOption({required this.value, required this.title, required this.description, required this.icon, required this.color});

  final String value;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}