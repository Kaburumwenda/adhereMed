import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/superadmin_models.dart';
import '../repository/superadmin_repository.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState
    extends State<SuperAdminDashboardScreen> {
  final _repo = SuperAdminRepository();
  PlatformStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await _repo.getStats();
      setState(() => _stats = stats);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1E293B),
                AppColors.primary.withValues(alpha: 0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.admin_panel_settings,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Super Admin Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Platform-wide monitoring & management',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh, color: Colors.white),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),

        // Body
        Expanded(
          child: _loading
              ? const LoadingWidget()
              : _error != null
                  ? _ErrorView(error: _error!, onRetry: _load)
                  : _Body(stats: _stats!, onRefresh: _load),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.stats, required this.onRefresh});
  final PlatformStats stats;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick nav buttons
            _QuickNav(),
            const SizedBox(height: 24),

            // Tenant stats row
            _SectionHeader(icon: Icons.business, title: 'Tenants', color: AppColors.primary),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (ctx, bc) {
              final cols = bc.maxWidth > 700 ? 4 : 2;
              return _grid(cols, [
                _StatCard(
                  label: 'Total Tenants',
                  value: '${stats.totalTenants}',
                  icon: Icons.business,
                  color: AppColors.primary,
                ),
                _StatCard(
                  label: 'Active',
                  value: '${stats.activeTenants}',
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                ),
                _StatCard(
                  label: 'Inactive',
                  value: '${stats.inactiveTenants}',
                  icon: Icons.cancel_outlined,
                  color: AppColors.error,
                ),
                _StatCard(
                  label: 'New (30d)',
                  value: '${stats.newTenants30d}',
                  icon: Icons.fiber_new_outlined,
                  color: AppColors.warning,
                ),
              ]);
            }),
            const SizedBox(height: 8),
            // By type
            if (stats.tenantsByType.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                children: stats.tenantsByType.map((t) {
                  final type = t['type'] as String? ?? '';
                  final count = t['count'] as int? ?? 0;
                  return _TypeChip(type: type, count: count);
                }).toList(),
              ),
            ],

            const SizedBox(height: 28),
            // User stats row
            _SectionHeader(icon: Icons.people, title: 'Users', color: AppColors.secondary),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (ctx, bc) {
              final cols = bc.maxWidth > 700 ? 4 : 2;
              return _grid(cols, [
                _StatCard(
                  label: 'Total Users',
                  value: '${stats.totalUsers}',
                  icon: Icons.people,
                  color: AppColors.secondary,
                ),
                _StatCard(
                  label: 'Active',
                  value: '${stats.activeUsers}',
                  icon: Icons.person_outline,
                  color: AppColors.success,
                ),
                _StatCard(
                  label: 'Inactive',
                  value: '${stats.inactiveUsers}',
                  icon: Icons.person_off_outlined,
                  color: AppColors.error,
                ),
                _StatCard(
                  label: 'New (30d)',
                  value: '${stats.newUsers30d}',
                  icon: Icons.person_add_outlined,
                  color: AppColors.warning,
                ),
              ]);
            }),

            // Users by role
            if (stats.usersByRole.isNotEmpty) ...[
              const SizedBox(height: 20),
              _SectionHeader(
                  icon: Icons.bar_chart,
                  title: 'Users by Role',
                  color: AppColors.textSecondary),
              const SizedBox(height: 12),
              _RoleBreakdownCard(roles: stats.usersByRole),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _QuickNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final buttons = [
      (Icons.business, 'Tenants', AppColors.primary, '/superadmin/tenants'),
      (Icons.people, 'All Users', AppColors.secondary, '/superadmin/users'),
      (Icons.person_add, 'New Tenant', AppColors.success, '/superadmin/tenants/new'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: buttons.map((b) {
        final (icon, label, color, path) = b;
        return FilledButton.icon(
          onPressed: () => context.push(path),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          icon: Icon(icon, size: 18),
          label: Text(label),
        );
      }).toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.icon, required this.title, required this.color});
  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type, required this.count});
  final String type;
  final int count;

  Color get _color {
    switch (type) {
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

  String get _label {
    switch (type) {
      case 'hospital':
        return 'Hospitals';
      case 'pharmacy':
        return 'Pharmacies';
      case 'lab':
        return 'Laboratories';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$_label: $count',
            style: TextStyle(
                color: _color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _RoleBreakdownCard extends StatelessWidget {
  const _RoleBreakdownCard({required this.roles});
  final List<Map<String, dynamic>> roles;

  @override
  Widget build(BuildContext context) {
    final total = roles.fold<int>(
        0, (sum, r) => sum + ((r['count'] as int?) ?? 0));
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: roles.map((r) {
            final role = r['role'] as String? ?? '';
            final count = r['count'] as int? ?? 0;
            final frac = total > 0 ? count / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      _roleLabel(role),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: frac,
                        minHeight: 8,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.secondary.withValues(alpha: 0.7)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '$count',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    final map = {
      'super_admin': 'Super Admin',
      'tenant_admin': 'Tenant Admin',
      'doctor': 'Doctor',
      'clinical_officer': 'Clinical Officer',
      'nurse': 'Nurse',
      'midwife': 'Midwife',
      'lab_tech': 'Lab Tech',
      'pharmacist': 'Pharmacist',
      'pharmacy_tech': 'Pharmacy Tech',
      'cashier': 'Cashier',
      'receptionist': 'Receptionist',
      'radiologist': 'Radiologist',
      'patient': 'Patient',
      'dentist': 'Dentist',
    };
    return map[role] ?? role;
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text('Failed to load stats', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(error, style: TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
        ],
      ),
    );
  }
}

Widget _grid(int cols, List<Widget> children) {
  if (cols == 1) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children.expand((w) => [w, const SizedBox(height: 12)]).toList()..removeLast(),
    );
  }
  final rows = <Widget>[];
  for (var i = 0; i < children.length; i += cols) {
    final rowItems = children.sublist(
        i, (i + cols) > children.length ? children.length : i + cols);
    while (rowItems.length < cols) {
      rowItems.add(const SizedBox.shrink());
    }
    rows.add(Row(
      children: rowItems
          .expand((w) => [Expanded(child: w), const SizedBox(width: 12)])
          .toList()
        ..removeLast(),
    ));
    if (i + cols < children.length) rows.add(const SizedBox(height: 12));
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
}
