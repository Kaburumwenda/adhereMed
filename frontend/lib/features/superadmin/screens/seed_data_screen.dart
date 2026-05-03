import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/superadmin_models.dart';
import '../repository/superadmin_repository.dart';

class SeedDataScreen extends StatefulWidget {
  const SeedDataScreen({super.key});

  @override
  State<SeedDataScreen> createState() => _SeedDataScreenState();
}

class _SeedDataScreenState extends State<SeedDataScreen> {
  final _repo = SuperAdminRepository();
  List<Map<String, dynamic>> _catalog = [];
  List<TenantAdminModel> _tenants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _repo.getSeedCatalog(),
        _repo.getTenants(),
      ]);
      setState(() {
        _catalog = results[0] as List<Map<String, dynamic>>;
        _tenants = results[1] as List<TenantAdminModel>;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.storage, size: 20, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Seed Data',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),

        // Body
        Expanded(
          child: _loading
              ? const LoadingWidget()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: Color(0xFF0284C7), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Seed commands populate a tenant with initial data such as medications, '
                                'pharmacy stock, and lab tests. Safe to run multiple times.',
                                style: TextStyle(
                                  color: const Color(0xFF0369A1),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Seed cards
                      ..._catalog.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _SeedCard(
                              item: item,
                              tenants: _tenants,
                              repo: _repo,
                            ),
                          )),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _SeedCard extends StatefulWidget {
  const _SeedCard({
    required this.item,
    required this.tenants,
    required this.repo,
  });
  final Map<String, dynamic> item;
  final List<TenantAdminModel> tenants;
  final SuperAdminRepository repo;

  @override
  State<_SeedCard> createState() => _SeedCardState();
}

class _SeedCardState extends State<_SeedCard> {
  int? _selectedTenantId;
  bool _reset = false;
  bool _running = false;
  String? _result;
  bool _success = false;

  String get _key => widget.item['key'] as String;
  String get _label => widget.item['label'] as String;
  String get _description => widget.item['description'] as String;
  String get _scope => widget.item['scope'] as String;
  bool get _isTenant => _scope == 'tenant';

  IconData get _icon {
    switch (_key) {
      case 'medications':
        return Icons.medication;
      case 'pharmacy_stock':
        return Icons.inventory_2;
      case 'lab_tests':
        return Icons.biotech;
      default:
        return Icons.storage;
    }
  }

  Color get _color {
    switch (_key) {
      case 'medications':
        return AppColors.primary;
      case 'pharmacy_stock':
        return AppColors.secondary;
      case 'lab_tests':
        return const Color(0xFF8B5CF6);
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _run() async {
    if (_isTenant && _selectedTenantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a tenant first.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Run "$_label"?'),
            content: Text(_isTenant
                ? 'This will seed data for the selected tenant.${_reset ? " Existing data will be reset." : ""}'
                : 'This will seed global data.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Run'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm) return;

    setState(() {
      _running = true;
      _result = null;
    });

    try {
      final data = await widget.repo.runSeed(
        command: _key,
        tenantId: _isTenant ? _selectedTenantId : null,
        reset: _reset,
      );
      setState(() {
        _result = data['detail'] as String? ?? 'Done';
        _success = true;
      });
    } catch (e) {
      setState(() {
        _result = '$e';
        _success = false;
      });
    } finally {
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_color.withValues(alpha: 0.1), _color.withValues(alpha: 0.04)],
              ),
            ),
            child: Row(
              children: [
                Icon(_icon, color: _color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _color,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _description,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isTenant
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _isTenant ? 'Per Tenant' : 'Global',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _isTenant
                          ? const Color(0xFF92400E)
                          : const Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tenant selector (for tenant-scoped commands)
                if (_isTenant) ...[
                  DropdownButtonFormField<int>(
                    initialValue: _selectedTenantId,
                    onChanged: (v) => setState(() => _selectedTenantId = v),
                    decoration: InputDecoration(
                      labelText: 'Select Tenant',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: widget.tenants.map((t) {
                      return DropdownMenuItem(
                        value: t.id,
                        child: Text('${t.name} (${t.typeLabel})',
                            overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                ],

                // Reset toggle (only for pharmacy_stock)
                if (_key == 'pharmacy_stock')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Switch(
                          value: _reset,
                          onChanged: (v) => setState(() => _reset = v),
                          activeTrackColor: AppColors.error.withValues(alpha: 0.4),
                          activeThumbColor: AppColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Reset existing data before seeding',
                          style: TextStyle(
                            fontSize: 12,
                            color: _reset ? AppColors.error : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Result message
                if (_result != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: _success
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _success
                            ? const Color(0xFFBBF7D0)
                            : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _success ? Icons.check_circle : Icons.error,
                          size: 16,
                          color: _success ? AppColors.success : AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _result!,
                            style: TextStyle(
                              fontSize: 12,
                              color: _success
                                  ? const Color(0xFF166534)
                                  : const Color(0xFF991B1B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Run button
                FilledButton.icon(
                  onPressed: _running ? null : _run,
                  style: FilledButton.styleFrom(
                    backgroundColor: _color,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: _running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow, size: 18),
                  label: Text(_running ? 'Seeding...' : 'Run Seed'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
