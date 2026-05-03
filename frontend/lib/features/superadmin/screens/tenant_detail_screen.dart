import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/superadmin_models.dart';
import '../repository/superadmin_repository.dart';

class TenantDetailScreen extends StatefulWidget {
  final String tenantId;
  const TenantDetailScreen({super.key, required this.tenantId});

  @override
  State<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends State<TenantDetailScreen> {
  final _repo = SuperAdminRepository();
  TenantAdminModel? _tenant;
  Map<String, dynamic>? _stats;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  // Edit controllers
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final id = int.parse(widget.tenantId);
      final results = await Future.wait([
        _repo.getTenant(id),
        _repo.getTenantStats(id),
      ]);
      final tenant = results[0] as TenantAdminModel;
      setState(() {
        _tenant = tenant;
        _stats = results[1] as Map<String, dynamic>;
        _nameCtrl.text = tenant.name;
        _cityCtrl.text = tenant.city;
        _addressCtrl.text = tenant.address;
        _phoneCtrl.text = tenant.phone;
        _emailCtrl.text = tenant.email;
        _websiteCtrl.text = tenant.website;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await _repo.updateTenant(int.parse(widget.tenantId), {
        'name': _nameCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
      });
      setState(() {
        _tenant = updated;
        _editing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tenant updated successfully.')));
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

  Future<void> _toggleActive() async {
    final t = _tenant!;
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(t.isActive ? 'Deactivate Tenant' : 'Activate Tenant'),
            content: Text(t.isActive
                ? 'This will disable access for all users in "${t.name}".'
                : 'This will restore access for all users in "${t.name}".'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Confirm')),
            ],
          ),
        ) ??
        false;
    if (!confirm) return;
    await _repo.toggleTenantActive(int.parse(widget.tenantId));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();
    if (_tenant == null) {
      return const Center(child: Text('Tenant not found'));
    }
    final t = _tenant!;

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
              Expanded(
                child: Text(t.name,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
              if (_editing) ...[
                TextButton(
                    onPressed: () => setState(() => _editing = false),
                    child: const Text('Cancel')),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: () => setState(() => _editing = true),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                _ToggleBtn(
                    isActive: t.isActive, onPressed: _toggleActive),
              ],
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero card
                _HeroCard(tenant: t),
                const SizedBox(height: 20),

                if (_editing)
                  _EditForm(
                    nameCtrl: _nameCtrl,
                    cityCtrl: _cityCtrl,
                    addressCtrl: _addressCtrl,
                    phoneCtrl: _phoneCtrl,
                    emailCtrl: _emailCtrl,
                    websiteCtrl: _websiteCtrl,
                  )
                else ...[
                  // Info card
                  _InfoCard(tenant: t),
                  const SizedBox(height: 16),
                  // Stats
                  if (_stats != null) _StatsCard(stats: _stats!),
                ],

                const SizedBox(height: 24),
                // Users button
                FilledButton.icon(
                  onPressed: () =>
                      context.push('/superadmin/users?tenant_id=${t.id}'),
                  icon: const Icon(Icons.people, size: 18),
                  label: Text('View Users (${t.userCount})'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({required this.isActive, required this.onPressed});
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
          side: BorderSide(
              color: isActive ? AppColors.error : AppColors.success)),
      onPressed: onPressed,
      icon: Icon(
          isActive ? Icons.block : Icons.check_circle,
          size: 16,
          color: isActive ? AppColors.error : AppColors.success),
      label: Text(
        isActive ? 'Deactivate' : 'Activate',
        style: TextStyle(
            color: isActive ? AppColors.error : AppColors.success),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.tenant});
  final TenantAdminModel tenant;

  Color get _typeColor {
    switch (tenant.type) {
      case 'hospital':
        return AppColors.primary;
      case 'pharmacy':
        return AppColors.secondary;
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.hardEdge,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_typeColor, _typeColor.withValues(alpha: 0.6)],
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    tenant.name.isNotEmpty
                        ? tenant.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tenant.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      Text(tenant.typeLabel,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      Text('/${tenant.slug}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: tenant.isActive
                        ? Colors.green.withValues(alpha: 0.25)
                        : Colors.red.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tenant.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                        color: tenant.isActive
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.tenant});
  final TenantAdminModel tenant;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Info',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
            const SizedBox(height: 12),
            _Row(Icons.location_city, 'City', tenant.city),
            _Row(Icons.flag, 'Country', tenant.country),
            _Row(Icons.home, 'Address', tenant.address),
            _Row(Icons.phone, 'Phone', tenant.phone),
            _Row(Icons.email, 'Email', tenant.email),
            _Row(Icons.link, 'Website', tenant.website),
            _Row(Icons.dns, 'Schema', tenant.schemaName),
            if (tenant.primaryDomain.isNotEmpty)
              _Row(Icons.language, 'Domain', tenant.primaryDomain),
            _Row(Icons.calendar_today, 'Created',
                tenant.createdAt.isNotEmpty
                    ? tenant.createdAt.substring(0, 10)
                    : ''),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
              width: 80,
              child: Text(label,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13))),
          IconButton(
            icon: const Icon(Icons.copy, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final users = stats['users'] as Map<String, dynamic>? ?? {};
    final byRole = (users['by_role'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User Stats',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary)),
            const SizedBox(height: 12),
            Row(children: [
              _SmallStat(
                  label: 'Total', value: '${users['total'] ?? 0}'),
              const SizedBox(width: 16),
              _SmallStat(
                  label: 'Active',
                  value: '${users['active'] ?? 0}',
                  color: AppColors.success),
              const SizedBox(width: 16),
              _SmallStat(
                  label: 'Inactive',
                  value:
                      '${((users['total'] ?? 0) - (users['active'] ?? 0))}',
                  color: AppColors.error),
            ]),
            if (byRole.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...byRole.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      SizedBox(
                          width: 120,
                          child: Text(_roleLabel(r['role'] as String? ?? ''),
                              style: const TextStyle(fontSize: 12))),
                      Text('${r['count'] ?? 0}',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                              fontSize: 12)),
                    ]),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    const map = {
      'super_admin': 'Super Admin',
      'tenant_admin': 'Tenant Admin',
      'doctor': 'Doctor',
      'nurse': 'Nurse',
      'pharmacist': 'Pharmacist',
      'patient': 'Patient',
      'lab_tech': 'Lab Tech',
      'cashier': 'Cashier',
      'receptionist': 'Receptionist',
    };
    return map[role] ?? role;
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color ?? AppColors.textPrimary)),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.nameCtrl,
    required this.cityCtrl,
    required this.addressCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.websiteCtrl,
  });
  final TextEditingController nameCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController websiteCtrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _TF('Name *', nameCtrl),
            const SizedBox(height: 12),
            _TF('City', cityCtrl),
            const SizedBox(height: 12),
            _TF('Address', addressCtrl, maxLines: 2),
            const SizedBox(height: 12),
            _TF('Phone', phoneCtrl, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _TF('Email', emailCtrl, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _TF('Website', websiteCtrl, keyboardType: TextInputType.url),
          ],
        ),
      ),
    );
  }
}

class _TF extends StatelessWidget {
  const _TF(this.label, this.ctrl,
      {this.maxLines = 1, this.keyboardType});
  final String label;
  final TextEditingController ctrl;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
