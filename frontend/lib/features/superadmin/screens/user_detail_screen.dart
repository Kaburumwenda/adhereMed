import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/superadmin_models.dart';
import '../repository/superadmin_repository.dart';

class UserDetailScreen extends StatefulWidget {
  final String userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final _repo = SuperAdminRepository();
  AdminUserModel? _user;
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;

  // Form controllers
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _role;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = await _repo.getUser(int.parse(widget.userId));
      setState(() {
        _user = user;
        _firstCtrl.text = user.firstName;
        _lastCtrl.text = user.lastName;
        _emailCtrl.text = user.email;
        _phoneCtrl.text = user.phone;
        _role = user.role;
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
      final updated = await _repo.updateUser(int.parse(widget.userId), {
        'first_name': _firstCtrl.text.trim(),
        'last_name': _lastCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'role': _role,
      });
      setState(() {
        _user = updated;
        _editing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User updated.')));
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
    final u = _user!;
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(u.isActive ? 'Deactivate User' : 'Activate User'),
            content: Text(u.isActive
                ? 'Disable login for ${u.fullName.isNotEmpty ? u.fullName : u.email}?'
                : 'Restore login for ${u.fullName.isNotEmpty ? u.fullName : u.email}?'),
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
    try {
      await _repo.toggleUserActive(int.parse(widget.userId));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _resetPassword() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a new password or leave blank to auto-generate.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Reset')),
        ],
      ),
    );
    if (result == null) return;
    try {
      final data = await _repo.resetUserPassword(
        int.parse(widget.userId),
        newPassword: result.isNotEmpty ? result : null,
      );
      final generated = data['new_password'] as String?;
      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Password Reset'),
            content: generated != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('New generated password:'),
                      const SizedBox(height: 8),
                      SelectableText(generated,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 1)),
                      const SizedBox(height: 8),
                      const Text(
                          'Copy and share this with the user.',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  )
                : const Text('Password has been updated successfully.'),
            actions: [
              FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();
    if (_user == null) return const Center(child: Text('User not found'));
    final u = _user!;

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
                child: Text(
                    u.fullName.isNotEmpty ? u.fullName : u.email,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ),
              if (_editing) ...[
                TextButton(
                    onPressed: () {
                      setState(() => _editing = false);
                      // restore values
                      _firstCtrl.text = u.firstName;
                      _lastCtrl.text = u.lastName;
                      _emailCtrl.text = u.email;
                      _phoneCtrl.text = u.phone;
                      _role = u.role;
                    },
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
              ] else
                OutlinedButton.icon(
                  onPressed: () => setState(() => _editing = true),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
            ],
          ),
        ),

        // Body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero
                _UserHero(user: u),
                const SizedBox(height: 20),

                if (_editing)
                  _EditSection(
                    firstCtrl: _firstCtrl,
                    lastCtrl: _lastCtrl,
                    emailCtrl: _emailCtrl,
                    phoneCtrl: _phoneCtrl,
                    role: _role,
                    onRoleChanged: (v) => setState(() => _role = v),
                  )
                else ...[
                  // Info
                  _InfoCard(user: u),
                  const SizedBox(height: 16),

                  // Actions
                  _ActionsCard(
                    user: u,
                    onToggleActive: _toggleActive,
                    onResetPassword: _resetPassword,
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────── sub-widgets ────────────────

class _UserHero extends StatelessWidget {
  const _UserHero({required this.user});
  final AdminUserModel user;

  Color get _roleColor {
    switch (user.role) {
      case 'super_admin':
        return const Color(0xFF7C3AED);
      case 'tenant_admin':
        return AppColors.secondary;
      case 'doctor':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [_roleColor, _roleColor.withValues(alpha: 0.6)]),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(
                user.firstName.isNotEmpty
                    ? user.firstName[0].toUpperCase()
                    : user.email[0].toUpperCase(),
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
                  Text(
                      user.fullName.isNotEmpty ? user.fullName : user.email,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  Text(user.email,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                  Text(user.roleLabel,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: user.isActive
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.red.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                user.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                    color: user.isActive
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.user});
  final AdminUserModel user;

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
            Text('User Information',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.primary)),
            const SizedBox(height: 12),
            _Row(Icons.email, 'Email', user.email),
            _Row(Icons.phone, 'Phone', user.phone),
            _Row(Icons.badge, 'Role', user.roleLabel),
            _Row(Icons.business, 'Facility', user.tenantName ?? ''),
            _Row(Icons.category, 'Facility Type', user.tenantType ?? ''),
            _Row(Icons.calendar_today, 'Joined',
                (user.dateJoined?.isNotEmpty ?? false)
                    ? user.dateJoined!.substring(0, 10)
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
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
              width: 90,
              child: Text(label,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.user,
    required this.onToggleActive,
    required this.onResetPassword,
  });
  final AdminUserModel user;
  final VoidCallback onToggleActive;
  final VoidCallback onResetPassword;

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Actions',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onResetPassword,
              icon: const Icon(Icons.lock_reset, size: 18),
              label: const Text('Reset Password'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: user.isActive
                          ? AppColors.error
                          : AppColors.success)),
              onPressed: onToggleActive,
              icon: Icon(
                  user.isActive ? Icons.block : Icons.check_circle,
                  size: 18,
                  color: user.isActive ? AppColors.error : AppColors.success),
              label: Text(
                user.isActive ? 'Deactivate Account' : 'Activate Account',
                style: TextStyle(
                    color: user.isActive
                        ? AppColors.error
                        : AppColors.success),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditSection extends StatelessWidget {
  const _EditSection({
    required this.firstCtrl,
    required this.lastCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.role,
    required this.onRoleChanged,
  });
  final TextEditingController firstCtrl;
  final TextEditingController lastCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final String? role;
  final ValueChanged<String?> onRoleChanged;

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
            Row(children: [
              Expanded(child: _TF('First Name', firstCtrl)),
              const SizedBox(width: 10),
              Expanded(child: _TF('Last Name', lastCtrl)),
            ]),
            const SizedBox(height: 12),
            _TF('Email', emailCtrl, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _TF('Phone', phoneCtrl, keyboard: TextInputType.phone),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: role,
              onChanged: onRoleChanged,
              decoration: InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'tenant_admin', child: Text('Tenant Admin')),
                DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                DropdownMenuItem(value: 'nurse', child: Text('Nurse')),
                DropdownMenuItem(
                    value: 'pharmacist', child: Text('Pharmacist')),
                DropdownMenuItem(
                    value: 'lab_tech', child: Text('Lab Tech')),
                DropdownMenuItem(
                    value: 'cashier', child: Text('Cashier')),
                DropdownMenuItem(
                    value: 'receptionist', child: Text('Receptionist')),
                DropdownMenuItem(
                    value: 'patient', child: Text('Patient')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TF extends StatelessWidget {
  const _TF(this.label, this.ctrl, {this.keyboard});
  final String label;
  final TextEditingController ctrl;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
