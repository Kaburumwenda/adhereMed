import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/superadmin_models.dart';
import '../repository/superadmin_repository.dart';

class TenantManagementScreen extends StatefulWidget {
  const TenantManagementScreen({super.key});

  @override
  State<TenantManagementScreen> createState() => _TenantManagementScreenState();
}

class _TenantManagementScreenState extends State<TenantManagementScreen> {
  final _repo = SuperAdminRepository();
  final _searchCtrl = TextEditingController();
  List<TenantAdminModel> _tenants = [];
  List<TenantAdminModel> _filtered = [];
  bool _loading = true;
  String _typeFilter = '';

  @override
  void initState() {
    super.initState();
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
      final list = await _repo.getTenants();
      setState(() {
        _tenants = list;
        _applyFilter();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _tenants.where((t) {
        final matchQ = q.isEmpty ||
            t.name.toLowerCase().contains(q) ||
            t.city.toLowerCase().contains(q) ||
            t.email.toLowerCase().contains(q);
        final matchType = _typeFilter.isEmpty || t.type == _typeFilter;
        return matchQ && matchType;
      }).toList();
    });
  }

  Future<void> _toggleActive(TenantAdminModel tenant) async {
    final confirm = await _showConfirmDialog(
      tenant.isActive
          ? 'Deactivate "${tenant.name}"?'
          : 'Activate "${tenant.name}"?',
      tenant.isActive
          ? 'This will disable access for all users in this tenant.'
          : 'This will restore access for all users in this tenant.',
    );
    if (!confirm) return;

    try {
      await _repo.toggleTenantActive(tenant.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back)),
              const Icon(Icons.business, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Tenant Management',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              FilledButton.icon(
                onPressed: () => context.push('/superadmin/tenants/new'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Tenant'),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary),
              ),
            ],
          ),
        ),

        // Filters
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => _applyFilter(),
                  decoration: InputDecoration(
                    hintText: 'Search tenants…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              _applyFilter();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _typeFilter.isEmpty ? null : _typeFilter,
                hint: const Text('All Types'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('All Types')),
                  DropdownMenuItem(value: 'hospital', child: Text('Hospital')),
                  DropdownMenuItem(
                      value: 'pharmacy', child: Text('Pharmacy')),
                  DropdownMenuItem(value: 'lab', child: Text('Laboratory')),
                ],
                onChanged: (v) {
                  setState(() => _typeFilter = v ?? '');
                  _applyFilter();
                },
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: _loading
              ? const LoadingWidget()
              : _filtered.isEmpty
                  ? Center(
                      child: Text('No tenants found',
                          style:
                              TextStyle(color: AppColors.textSecondary)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _TenantCard(
                          tenant: _filtered[i],
                          onToggleActive: () => _toggleActive(_filtered[i]),
                          onTap: () =>
                              context.push('/superadmin/tenants/${_filtered[i].id}'),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _TenantCard extends StatelessWidget {
  const _TenantCard({
    required this.tenant,
    required this.onToggleActive,
    required this.onTap,
  });
  final TenantAdminModel tenant;
  final VoidCallback onToggleActive;
  final VoidCallback onTap;

  Color get _typeColor {
    switch (tenant.type) {
      case 'hospital':
        return AppColors.primary;
      case 'pharmacy':
        return AppColors.secondary;
      case 'lab':
        return const Color(0xFF8B5CF6);
      default:
        return AppColors.textSecondary;
    }
  }

  IconData get _typeIcon {
    switch (tenant.type) {
      case 'hospital':
        return Icons.local_hospital;
      case 'pharmacy':
        return Icons.local_pharmacy;
      case 'lab':
        return Icons.biotech;
      default:
        return Icons.business;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: tenant.isActive
                ? AppColors.border
                : AppColors.error.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_typeIcon, color: _typeColor, size: 24),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tenant.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tenant.typeLabel,
                            style: TextStyle(
                                color: _typeColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (tenant.city.isNotEmpty || tenant.country.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text(
                            [tenant.city, tenant.country]
                                .where((s) => s.isNotEmpty)
                                .join(', '),
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    if (tenant.email.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.email_outlined,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text(tenant.email,
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.people_outline,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Text('${tenant.userCount} users',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(width: 12),
                        if (tenant.primaryDomain.isNotEmpty) ...[
                          Icon(Icons.link,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text(tenant.primaryDomain,
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status + Toggle
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: tenant.isActive
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tenant.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                          color: tenant.isActive
                              ? AppColors.success
                              : AppColors.error,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Switch(
                    value: tenant.isActive,
                    onChanged: (_) => onToggleActive(),
                    activeThumbColor: AppColors.success,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
