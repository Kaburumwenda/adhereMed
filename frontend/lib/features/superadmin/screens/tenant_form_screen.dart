import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../repository/superadmin_repository.dart';

class TenantFormScreen extends StatefulWidget {
  const TenantFormScreen({super.key});

  @override
  State<TenantFormScreen> createState() => _TenantFormScreenState();
}

class _TenantFormScreenState extends State<TenantFormScreen> {
  final _repo = SuperAdminRepository();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  // Tenant fields
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _domainCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'Somalia');
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _type = 'hospital';

  // Admin user fields
  final _adminEmailCtrl = TextEditingController();
  final _adminFirstCtrl = TextEditingController();
  final _adminLastCtrl = TextEditingController();
  final _adminPasswordCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _domainCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminFirstCtrl.dispose();
    _adminLastCtrl.dispose();
    _adminPasswordCtrl.dispose();
    super.dispose();
  }

  void _autoSlug(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    _slugCtrl.text = slug;
    _domainCtrl.text = '$slug.adheremed.com';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = {
        'name': _nameCtrl.text.trim(),
        'slug': _slugCtrl.text.trim(),
        'type': _type,
        'domain': _domainCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'country': _countryCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'admin_email': _adminEmailCtrl.text.trim(),
        'admin_first_name': _adminFirstCtrl.text.trim(),
        'admin_last_name': _adminLastCtrl.text.trim(),
        'admin_password': _adminPasswordCtrl.text,
      };
      final result = await _repo.createTenant(payload);
      final tenantName = result['name'] as String? ?? _nameCtrl.text.trim();
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Tenant Created'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$tenantName has been created.'),
                const SizedBox(height: 12),
                const Text('Admin credentials:',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Text('Email: ${_adminEmailCtrl.text.trim()}'),
                Text('Password: ${_adminPasswordCtrl.text.isNotEmpty ? _adminPasswordCtrl.text : "(auto-generated)"}'),
              ],
            ),
            actions: [
              FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done')),
            ],
          ),
        );
        if (mounted) context.go('/superadmin/tenants');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(
            children: [
              IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back)),
              const SizedBox(width: 4),
              const Expanded(
                child: Text('New Tenant',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Create'),
              ),
            ],
          ),
        ),

        // Body
        Expanded(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Tenant section
                  _Section(
                    icon: Icons.business,
                    title: 'Tenant Information',
                    color: AppColors.primary,
                    children: [
                      _TF(label: 'Facility Name *',
                          ctrl: _nameCtrl,
                          validator: _required,
                          onChanged: _autoSlug),
                      _grid([
                        _TF(label: 'Slug *',
                            ctrl: _slugCtrl,
                            validator: _required,
                            hint: 'e.g. city_hospital'),
                        DropdownButtonFormField<String>(
                          initialValue: _type,
                          onChanged: (v) => setState(() => _type = v!),
                          decoration: _dec('Type'),
                          items: const [
                            DropdownMenuItem(
                                value: 'hospital',
                                child: Text('Hospital')),
                            DropdownMenuItem(
                                value: 'pharmacy',
                                child: Text('Pharmacy')),
                            DropdownMenuItem(
                                value: 'lab',
                                child: Text('Lab')),
                          ],
                        ),
                      ]),
                      _TF(label: 'Domain *',
                          ctrl: _domainCtrl,
                          validator: _required,
                          hint: 'e.g. city_hospital.adheremed.com'),
                      _grid([
                        _TF(label: 'City', ctrl: _cityCtrl),
                        _TF(label: 'Country', ctrl: _countryCtrl),
                      ]),
                      _TF(
                          label: 'Address',
                          ctrl: _addressCtrl,
                          maxLines: 2),
                      _grid([
                        _TF(
                            label: 'Phone',
                            ctrl: _phoneCtrl,
                            keyboardType: TextInputType.phone),
                        _TF(
                            label: 'Email',
                            ctrl: _emailCtrl,
                            keyboardType: TextInputType.emailAddress),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Admin user section
                  _Section(
                    icon: Icons.admin_panel_settings,
                    title: 'Admin User',
                    color: AppColors.secondary,
                    children: [
                      _grid([
                        _TF(
                            label: 'First Name *',
                            ctrl: _adminFirstCtrl,
                            validator: _required),
                        _TF(
                            label: 'Last Name *',
                            ctrl: _adminLastCtrl,
                            validator: _required),
                      ]),
                      _TF(
                          label: 'Admin Email *',
                          ctrl: _adminEmailCtrl,
                          validator: _required,
                          keyboardType: TextInputType.emailAddress),
                      _TF(
                          label: 'Password (leave blank to auto-generate)',
                          ctrl: _adminPasswordCtrl,
                          obscure: true),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _grid(List<Widget> children) {
    return Row(
      children: children
          .map((w) => Expanded(child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: w,
              )))
          .toList(),
    );
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;
}

// ──────────────────── helpers ────────────────────

class _TF extends StatelessWidget {
  const _TF({
    required this.label,
    required this.ctrl,
    this.validator,
    this.hint,
    this.onChanged,
    this.maxLines = 1,
    this.keyboardType,
    this.obscure = false,
  });
  final String label;
  final TextEditingController ctrl;
  final FormFieldValidator<String>? validator;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        validator: validator,
        maxLines: maxLines,
        keyboardType: keyboardType,
        obscureText: obscure,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.color,
    required this.children,
  });
  final IconData icon;
  final String title;
  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: color.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ],
            ),
          ),
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children)),
        ],
      ),
    );
  }
}
