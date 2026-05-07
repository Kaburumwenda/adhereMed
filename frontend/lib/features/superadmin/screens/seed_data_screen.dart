import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/superadmin_models.dart';
import '../repository/superadmin_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Seed item metadata
// ─────────────────────────────────────────────────────────────────────────────

IconData _seedIcon(String key) {
  switch (key) {
    case 'medications':
      return Icons.medication_rounded;
    case 'pharmacy_stock':
      return Icons.inventory_2_rounded;
    case 'lab_tests':
      return Icons.biotech_rounded;
    default:
      return Icons.storage_rounded;
  }
}

Color _seedColor(String key) {
  switch (key) {
    case 'medications':
      return const Color(0xFF0D9488);
    case 'pharmacy_stock':
      return const Color(0xFF6366F1);
    case 'lab_tests':
      return const Color(0xFF8B5CF6);
    default:
      return const Color(0xFF64748B);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

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
      final results = await Future.wait([
        _repo.getSeedCatalog(),
        _repo.getTenants(),
      ]);
      setState(() {
        _catalog = results[0] as List<Map<String, dynamic>>;
        _tenants = results[1] as List<TenantAdminModel>;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Gradient header ──────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2D1B69), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.storage_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Seed Data',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        Text('Populate tenants with initial reference data',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  // Catalog count chip
                  if (!_loading)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.layers,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 5),
                          Text('${_catalog.length} commands',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // ── Body ─────────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const LoadingWidget()
              : _error != null
                  ? _ErrorState(message: _error!, onRetry: _load)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                      children: [
                        // Info banner
                        _InfoBanner(
                          icon: Icons.info_outline_rounded,
                          color: const Color(0xFF0284C7),
                          bgColor: const Color(0xFF0284C7).withValues(alpha: 0.08),
                          borderColor:
                              const Color(0xFF0284C7).withValues(alpha: 0.25),
                          message:
                              'Seed commands populate a tenant with initial data such as '
                              'medications, pharmacy stock, and lab tests. '
                              'Safe to run multiple times.',
                        ),
                        const SizedBox(height: 8),
                        _InfoBanner(
                          icon: Icons.group_outlined,
                          color: const Color(0xFF7C3AED),
                          bgColor: const Color(0xFF7C3AED).withValues(alpha: 0.06),
                          borderColor:
                              const Color(0xFF7C3AED).withValues(alpha: 0.2),
                          message:
                              '${_tenants.length} tenant${_tenants.length == 1 ? '' : 's'} '
                              'available. Tenant-scoped commands require selecting one.',
                        ),
                        const SizedBox(height: 24),

                        // Section label
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text('Available Seed Commands',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5)),
                        ),

                        // Seed cards
                        ..._catalog.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _SeedCard(
                                item: item,
                                tenants: _tenants,
                                repo: _repo,
                              ),
                            )),
                      ],
                    ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info banner
// ─────────────────────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final String message;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 12, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            const Text('Failed to load seed catalog',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seed card
// ─────────────────────────────────────────────────────────────────────────────

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

  IconData get _icon => _seedIcon(_key);
  Color get _color => _seedColor(_key);

  Future<void> _run() async {
    if (_isTenant && _selectedTenantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a tenant first.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selectedName = _isTenant
        ? widget.tenants
            .firstWhere((t) => t.id == _selectedTenantId,
                orElse: () => widget.tenants.first)
            .name
        : null;

    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => _ConfirmDialog(
            label: _label,
            color: _color,
            icon: _icon,
            tenantName: selectedName,
            willReset: _reset,
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
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left color accent
              Container(width: 4, color: _color),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Card header row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: _color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_icon, color: _color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_label,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary)),
                                const SizedBox(height: 2),
                                Text(_description,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        height: 1.4)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Scope badge
                          _ScopeBadge(isTenant: _isTenant),
                        ],
                      ),
                    ),

                    Divider(height: 1, color: AppColors.border),

                    // Card body
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Tenant selector
                          if (_isTenant) ...[
                            DropdownButtonFormField<int>(
                              value: _selectedTenantId,
                              onChanged: (v) =>
                                  setState(() => _selectedTenantId = v),
                              decoration: InputDecoration(
                                hintText: 'Select a tenant…',
                                hintStyle: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary),
                                prefixIcon: Icon(Icons.business_rounded,
                                    size: 17,
                                    color: AppColors.textSecondary),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 11),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide:
                                        BorderSide(color: AppColors.border)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                        color: _color, width: 1.5)),
                                filled: true,
                                fillColor: AppColors.background,
                              ),
                              items: widget.tenants.map((t) {
                                return DropdownMenuItem(
                                  value: t.id,
                                  child: Text('${t.name} · ${t.typeLabel}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Reset toggle
                          if (_key == 'pharmacy_stock') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _reset
                                    ? AppColors.error.withValues(alpha: 0.06)
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: _reset
                                        ? AppColors.error.withValues(alpha: 0.3)
                                        : AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.restart_alt_rounded,
                                      size: 16,
                                      color: _reset
                                          ? AppColors.error
                                          : AppColors.textSecondary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Reset existing stock before seeding',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: _reset
                                              ? AppColors.error
                                              : AppColors.textSecondary),
                                    ),
                                  ),
                                  Switch(
                                    value: _reset,
                                    onChanged: (v) =>
                                        setState(() => _reset = v),
                                    activeTrackColor:
                                        AppColors.error.withValues(alpha: 0.4),
                                    activeThumbColor: AppColors.error,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Result message
                          if (_result != null) ...[
                            _ResultBanner(
                                success: _success, message: _result!),
                            const SizedBox(height: 10),
                          ],

                          // Run button
                          FilledButton.icon(
                            onPressed: _running ? null : _run,
                            style: FilledButton.styleFrom(
                              backgroundColor: _color,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              textStyle: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            icon: _running
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white))
                                : const Icon(Icons.play_arrow_rounded,
                                    size: 18),
                            label:
                                Text(_running ? 'Seeding…' : 'Run Seed'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scope badge
// ─────────────────────────────────────────────────────────────────────────────

class _ScopeBadge extends StatelessWidget {
  final bool isTenant;
  const _ScopeBadge({required this.isTenant});

  @override
  Widget build(BuildContext context) {
    final color =
        isTenant ? const Color(0xFFD97706) : const Color(0xFF059669);
    final label = isTenant ? 'Per Tenant' : 'Global';
    final icon = isTenant ? Icons.group : Icons.public;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result banner
// ─────────────────────────────────────────────────────────────────────────────

class _ResultBanner extends StatelessWidget {
  final bool success;
  final String message;
  const _ResultBanner({required this.success, required this.message});

  @override
  Widget build(BuildContext context) {
    final color = success ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(success ? Icons.check_circle_rounded : Icons.error_rounded,
              size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confirm dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final String? tenantName;
  final bool willReset;

  const _ConfirmDialog({
    required this.label,
    required this.color,
    required this.icon,
    this.tenantName,
    this.willReset = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: EdgeInsets.zero,
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
          ),
          border: Border(
              bottom: BorderSide(color: color.withValues(alpha: 0.2))),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Run "$label"?',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 17),
              onPressed: () => Navigator.pop(context, false),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
      content: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tenantName != null) ...[
              Row(
                children: [
                  Icon(Icons.business_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('Tenant: ',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                  Text(tenantName!,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Text(
              tenantName != null
                  ? 'This will seed data for the selected tenant.'
                  : 'This will seed global reference data.',
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.4),
            ),
            if (willReset) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 15, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reset is enabled — existing stock will be cleared before seeding.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: Icon(icon, size: 15),
          label: const Text('Run'),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}
