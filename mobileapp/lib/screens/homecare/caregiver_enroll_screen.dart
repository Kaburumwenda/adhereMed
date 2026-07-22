import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import 'hc_common.dart';

const _categories = [
  ('nurse', 'Nurse', Icons.medical_services_rounded),
  ('doctor', 'Doctor', Icons.local_hospital_rounded),
  ('physio', 'Physiotherapist', Icons.accessibility_new_rounded),
  ('hca', 'Health Care Assistant', Icons.volunteer_activism_rounded),
  ('nutritionist', 'Nutritionist', Icons.restaurant_rounded),
  ('other', 'Other', Icons.badge_rounded),
];

/// Enroll a caregiver (creates login + professional profile).
class HomecareCaregiverEnrollScreen extends ConsumerStatefulWidget {
  const HomecareCaregiverEnrollScreen({super.key});

  @override
  ConsumerState<HomecareCaregiverEnrollScreen> createState() =>
      _HomecareCaregiverEnrollScreenState();
}

class _HomecareCaregiverEnrollScreenState
    extends ConsumerState<HomecareCaregiverEnrollScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _license = TextEditingController();
  final _specialties = TextEditingController();
  final _rate = TextEditingController();
  final _bio = TextEditingController();

  String _category = 'nurse';
  bool _isAvailable = true;
  bool _isIndependent = false;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add caregiver')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: hcRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(_error!,
                    style: const TextStyle(color: hcRed, fontSize: 13)),
              ),
            Text('CATEGORY',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories
                  .map((c) => ChoiceChip(
                        selected: _category == c.$1,
                        avatar: Icon(c.$3, size: 16),
                        label: Text(c.$2),
                        onSelected: (_) =>
                            setState(() => _category = c.$1),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _firstName,
                  decoration:
                      const InputDecoration(labelText: 'First name *'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Last name *'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Email *', prefixIcon: Icon(Icons.mail_rounded)),
              validator: (v) =>
                  !(v ?? '').contains('@') ? 'Valid email required' : null,
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.call_rounded)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Password (optional)',
                      prefixIcon: Icon(Icons.lock_rounded)),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _license,
                  decoration:
                      const InputDecoration(labelText: 'License number'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _rate,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Hourly rate', prefixText: 'KSh '),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextFormField(
              controller: _specialties,
              decoration: const InputDecoration(
                  labelText: 'Specialties (comma-separated)'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _bio,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Short bio'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isAvailable,
              title: const Text('Available for visits'),
              onChanged: (v) => setState(() => _isAvailable = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isIndependent,
              title: const Text('Independent contractor'),
              onChanged: (v) => setState(() => _isIndependent = v),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                  backgroundColor: hcBlue,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Create caregiver'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/homecare/caregivers/enroll/', data: {
        'category': _category,
        'user_email': _email.text.trim(),
        'first_name': _firstName.text.trim(),
        'last_name': _lastName.text.trim(),
        'phone': _phone.text.trim(),
        if (_password.text.isNotEmpty) 'password': _password.text,
        'license_number': _license.text.trim(),
        'specialties': _specialties.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        'bio': _bio.text.trim(),
        'hourly_rate': double.tryParse(_rate.text) ?? 0,
        'is_available': _isAvailable,
        'is_independent': _isIndependent,
      });
      if (mounted) {
        final id = res.data?['id'];
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Caregiver created')));
        if (id != null) {
          context.go('/homecare/caregivers/$id');
        } else {
          context.go('/homecare/caregivers');
        }
      }
    } catch (e) {
      String msg = 'Could not create caregiver.';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map) {
          msg = data['detail']?.toString() ??
              data.entries
                  .map((en) =>
                      '${en.key}: ${en.value is List ? (en.value as List).join(', ') : en.value}')
                  .join('\n');
        }
      } catch (_) {}
      if (mounted) setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
