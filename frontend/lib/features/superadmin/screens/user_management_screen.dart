import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/superadmin_models.dart';
import '../repository/superadmin_repository.dart';

class UserManagementScreen extends StatefulWidget {
  final String? initialTenantId;
  const UserManagementScreen({super.key, this.initialTenantId});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _repo = SuperAdminRepository();
  List<AdminUserModel> _users = [];
  bool _loading = true;

  final _searchCtrl = TextEditingController();
  String? _roleFilter;
  String? _tenantIdFilter;
  bool? _activeFilter;

  @override
  void initState() {
    super.initState();
    _tenantIdFilter = widget.initialTenantId;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await _repo.getUsers(
        q: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : '',
        role: _roleFilter ?? '',
        tenantId: _tenantIdFilter ?? '',
        isActive: _activeFilter == null
            ? ''
            : (_activeFilter! ? 'true' : 'false'),
      );
      setState(() => _users = users);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
                  child: Text('All Users',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700))),
              Text('${_users.length}',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),

        // Filters
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.background,
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  hintText: 'Search by name, email or phone...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _load();
                          })
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.border)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _Dropdown<String?>(
                    value: _roleFilter,
                    hint: 'All Roles',
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Roles')),
                      DropdownMenuItem(
                          value: 'super_admin', child: Text('Super Admin')),
                      DropdownMenuItem(
                          value: 'tenant_admin', child: Text('Tenant Admin')),
                      DropdownMenuItem(
                          value: 'doctor', child: Text('Doctor')),
                      DropdownMenuItem(
                          value: 'nurse', child: Text('Nurse')),
                      DropdownMenuItem(
                          value: 'pharmacist', child: Text('Pharmacist')),
                      DropdownMenuItem(
                          value: 'lab_tech', child: Text('Lab Tech')),
                      DropdownMenuItem(
                          value: 'cashier', child: Text('Cashier')),
                      DropdownMenuItem(
                          value: 'receptionist',
                          child: Text('Receptionist')),
                      DropdownMenuItem(
                          value: 'patient', child: Text('Patient')),
                    ],
                    onChanged: (v) {
                      setState(() => _roleFilter = v);
                      _load();
                    },
                  )),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _Dropdown<bool?>(
                    value: _activeFilter,
                    hint: 'All Status',
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Status')),
                      DropdownMenuItem(
                          value: true, child: Text('Active')),
                      DropdownMenuItem(
                          value: false, child: Text('Inactive')),
                    ],
                    onChanged: (v) {
                      setState(() => _activeFilter = v);
                      _load();
                    },
                  )),
                ],
              ),
            ],
          ),
        ),

        // Body
        Expanded(
          child: _loading
              ? const LoadingWidget()
              : _users.isEmpty
                  ? const Center(child: Text('No users found'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _UserCard(
                          user: _users[i],
                          onTap: () =>
                              context.push('/superadmin/users/${_users[i].id}')),
                    ),
        ),
      ],
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });
  final T value;
  final String hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      onChanged: onChanged,
      isDense: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.border)),
      ),
      items: items,
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onTap});
  final AdminUserModel user;
  final VoidCallback onTap;

  Color get _roleColor {
    switch (user.role) {
      case 'super_admin':
        return const Color(0xFF7C3AED);
      case 'tenant_admin':
        return AppColors.secondary;
      case 'doctor':
        return AppColors.primary;
      case 'nurse':
        return const Color(0xFF0891B2);
      case 'pharmacist':
        return const Color(0xFF059669);
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppColors.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: _roleColor.withValues(alpha: 0.15),
                child: Text(
                  user.firstName.isNotEmpty
                      ? user.firstName[0].toUpperCase()
                      : user.email[0].toUpperCase(),
                  style: TextStyle(
                      color: _roleColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.fullName.isNotEmpty
                                ? user.fullName
                                : user.email,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ),
                        _Badge(user.roleLabel, _roleColor),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(user.email,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                    if (user.tenantName != null && user.tenantName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.business,
                              size: 11, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text(user.tenantName ?? '',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Active dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: user.isActive ? AppColors.success : AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 18, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}
