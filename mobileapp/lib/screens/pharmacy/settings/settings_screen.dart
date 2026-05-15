import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api.dart';
import '../../../core/theme_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/common.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════
final _profileProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final results = await Future.wait([
    dio.get('/auth/me/'),
    dio.get('/pharmacy-profile/profile/'),
  ]);
  final pharmaData = results[1].data;
  final pharma = pharmaData is List
      ? (pharmaData.isNotEmpty ? pharmaData[0] : {})
      : (pharmaData?['results'] is List
          ? ((pharmaData['results'] as List).isNotEmpty ? pharmaData['results'][0] : {})
          : pharmaData ?? {});
  return {'user': results[0].data, 'pharmacy': pharma};
});

// ═══════════════════════════════════════════════════════════════════════════
//  DAYS / SERVICES CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════
const _weekDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
const _defaultServices = [
  'Prescription Dispensing', 'OTC Medications', 'Health Consultations',
  'Vaccinations', 'Blood Pressure Monitoring', 'Diabetes Screening',
  'Drug Interaction Check', 'Compounding', 'Home Delivery',
  'Insurance Processing', 'Health Education', 'First Aid',
];
const _defaultInsurers = [
  'NHIF', 'Jubilee', 'UAP', 'AAR', 'Britam', 'GA Insurance',
  'CIC Insurance', 'APA Insurance', 'Resolution Insurance', 'Madison Insurance',
];

// ═══════════════════════════════════════════════════════════════════════════
//  SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _tabs = const ['Profile', 'Hours', 'Services', 'Insurance', 'Security', 'About'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _ProfileTab(ref: ref),
          _OperatingHoursTab(ref: ref),
          _ServicesTab(ref: ref),
          _InsuranceTab(ref: ref),
          _SecurityTab(ref: ref),
          _AboutTab(ref: ref),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 1 — PROFILE
// ═══════════════════════════════════════════════════════════════════════════
class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final profile = ref.watch(_profileProvider);
    final themeMode = ref.watch(themeModeProvider);

    return ListView(padding: const EdgeInsets.all(16), children: [
      // User profile card
      Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(colors: [cs.primary.withValues(alpha: 0.08), cs.primary.withValues(alpha: 0.02)],
              begin: Alignment.topLeft, end: Alignment.bottomRight)),
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            CircleAvatar(radius: 32, backgroundColor: cs.primary.withValues(alpha: 0.15),
              child: Text(auth.user?.initials ?? '?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.primary))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(auth.user?.fullName ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(auth.user?.email ?? '', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 4),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text((auth.user?.role ?? '').replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(color: cs.primary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
            ])),
            IconButton(icon: const Icon(Icons.edit_rounded, size: 20), onPressed: () => _showEditProfile(context, ref)),
          ]),
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),
      const SizedBox(height: 16),

      // Pharmacy info
      profile.when(
        loading: () => const LoadingShimmer(lines: 3),
        error: (_, __) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_profileProvider)),
        data: (d) {
          final ph = d['pharmacy'] as Map? ?? {};
          final logo = ph['logo']?.toString() ?? '';
          return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.local_pharmacy_rounded, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Pharmacy Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  TextButton.icon(icon: const Icon(Icons.edit_rounded, size: 14),
                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                    onPressed: () => _showEditPharmacy(context, ref, ph)),
                ]),
                const Divider(height: 20),
                if (logo.isNotEmpty) ...[
                  Center(child: ClipRRect(borderRadius: BorderRadius.circular(12),
                    child: Image.network(logo, height: 80, errorBuilder: (_, __, ___) => const SizedBox()))),
                  const SizedBox(height: 12),
                ],
                _InfoRow(icon: Icons.store_rounded, label: 'Name', value: ph['name']?.toString() ?? '-'),
                _InfoRow(icon: Icons.badge_rounded, label: 'License', value: ph['license_number']?.toString() ?? '-'),
                if ((ph['description'] ?? '').toString().isNotEmpty)
                  _InfoRow(icon: Icons.description_rounded, label: 'About', value: ph['description']),
              ]),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.05, end: 0);
        },
      ),
      const SizedBox(height: 16),

      // Theme
      Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
          child: Column(children: [
            ListTile(leading: Icon(Icons.palette_rounded, color: cs.primary),
              title: const Text('Appearance', style: TextStyle(fontWeight: FontWeight.w700))),
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SegmentedButton<ThemeMode>(
                selected: {themeMode},
                onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_rounded, size: 18)),
                  ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded, size: 18)),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded, size: 18)),
                ],
              ),
            ),
          ]),
        ),
      ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.05, end: 0),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 2 — OPERATING HOURS
// ═══════════════════════════════════════════════════════════════════════════
class _OperatingHoursTab extends StatelessWidget {
  const _OperatingHoursTab({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final profile = ref.watch(_profileProvider);

    return profile.when(
      loading: () => const LoadingShimmer(),
      error: (_, __) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_profileProvider)),
      data: (d) {
        final ph = d['pharmacy'] as Map? ?? {};
        final hours = (ph['operating_hours'] as Map?) ?? {};
        final openDays = _weekDays.where((day) {
          final dh = hours[day];
          return dh is Map && dh['open'] == true;
        }).length;

        return ListView(padding: const EdgeInsets.all(16), children: [
          // KPI
          Container(
            margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Text('Open $openDays of 7 days', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6))),
            ]),
          ).animate().fadeIn(duration: 400.ms),

          // Quick presets
          Row(children: [
            const Text('Quick Presets', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const Spacer(),
            _PresetChip(label: 'Weekdays', onTap: () => _applyPreset(context, ref, ph, 'weekdays')),
            const SizedBox(width: 6),
            _PresetChip(label: 'Every Day', onTap: () => _applyPreset(context, ref, ph, 'everyday')),
            const SizedBox(width: 6),
            _PresetChip(label: '24/7', onTap: () => _applyPreset(context, ref, ph, '24_7')),
          ]),
          const SizedBox(height: 12),

          // Day cards
          ..._weekDays.asMap().entries.map((e) {
            final i = e.key;
            final day = e.value;
            final dh = (hours[day] as Map?) ?? {};
            final isOpen = dh['open'] == true;
            final openTime = dh['from']?.toString() ?? '08:00';
            final closeTime = dh['to']?.toString() ?? '18:00';
            final dayLabel = '${day[0].toUpperCase()}${day.substring(1)}';

            return Card(elevation: 0, margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isOpen ? const Color(0xFF10B981).withValues(alpha: 0.3) : cs.outlineVariant.withValues(alpha: 0.3))),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  SizedBox(width: 90, child: Text(dayLabel, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                    color: isOpen ? cs.onSurface : cs.onSurfaceVariant))),
                  Switch(value: isOpen, onChanged: (v) => _updateDay(context, ref, ph, day, open: v)),
                  if (isOpen) ...[
                    const SizedBox(width: 8),
                    _TimeChip(time: openTime, onTap: () => _pickTime(context, ref, ph, day, 'from', openTime)),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('–', style: TextStyle(color: cs.onSurfaceVariant))),
                    _TimeChip(time: closeTime, onTap: () => _pickTime(context, ref, ph, day, 'to', closeTime)),
                  ] else
                    Text('Closed', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
                ]),
              ),
            ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: (30 * i).clamp(0, 200)));
          }),
        ]);
      },
    );
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref, Map ph, String day, String field, String current) async {
    final parts = current.split(':');
    final init = TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
    final picked = await showTimePicker(context: context, initialTime: init);
    if (picked == null || !context.mounted) return;
    final time = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    _updateDay(context, ref, ph, day, timeField: field, timeValue: time);
  }

  void _updateDay(BuildContext context, WidgetRef ref, Map ph, String day,
      {bool? open, String? timeField, String? timeValue}) async {
    final hours = Map<String, dynamic>.from((ph['operating_hours'] as Map?) ?? {});
    final dh = Map<String, dynamic>.from((hours[day] as Map?) ?? {'open': false, 'from': '08:00', 'to': '18:00'});
    if (open != null) dh['open'] = open;
    if (timeField != null && timeValue != null) dh[timeField] = timeValue;
    hours[day] = dh;
    await _patchProfile(context, ref, ph, {'operating_hours': hours});
  }

  void _applyPreset(BuildContext context, WidgetRef ref, Map ph, String preset) async {
    final hours = <String, dynamic>{};
    for (final day in _weekDays) {
      switch (preset) {
        case 'weekdays':
          final isWeekday = !['saturday', 'sunday'].contains(day);
          hours[day] = {'open': isWeekday, 'from': '08:00', 'to': '18:00'};
        case 'everyday':
          hours[day] = {'open': true, 'from': '08:00', 'to': '18:00'};
        case '24_7':
          hours[day] = {'open': true, 'from': '00:00', 'to': '23:59'};
      }
    }
    await _patchProfile(context, ref, ph, {'operating_hours': hours});
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 3 — DELIVERY & SERVICES
// ═══════════════════════════════════════════════════════════════════════════
class _ServicesTab extends StatelessWidget {
  const _ServicesTab({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final profile = ref.watch(_profileProvider);

    return profile.when(
      loading: () => const LoadingShimmer(),
      error: (_, __) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_profileProvider)),
      data: (d) {
        final ph = d['pharmacy'] as Map? ?? {};
        final services = List<String>.from((ph['services'] as List?) ?? []);
        final radius = double.tryParse('${ph['delivery_radius_km'] ?? 0}') ?? 0;
        final fee = double.tryParse('${ph['delivery_fee'] ?? 0}') ?? 0;

        return ListView(padding: const EdgeInsets.all(16), children: [
          // Delivery section
          _SectionCard(title: 'Delivery Settings', icon: Icons.delivery_dining_rounded,
            children: [
              _InfoRow(icon: Icons.radar_rounded, label: 'Radius', value: '${radius.toStringAsFixed(1)} km'),
              _InfoRow(icon: Icons.payments_rounded, label: 'Fee', value: 'KSH ${fee.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _showEditDelivery(context, ref, ph),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit Delivery Settings'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 16),

          // Services section
          _SectionCard(title: 'Services Offered (${services.length})', icon: Icons.medical_services_rounded,
            children: [
              if (services.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No services configured', style: TextStyle(color: Colors.grey, fontSize: 13))),
              Wrap(spacing: 6, runSpacing: 6, children: services.map((s) => Chip(
                label: Text(s, style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close_rounded, size: 14),
                onDeleted: () {
                  final updated = List<String>.from(services)..remove(s);
                  _patchProfile(context, ref, ph, {'services': updated});
                },
              )).toList()),
              const SizedBox(height: 12),
              _AddChipButton(
                suggestions: _defaultServices.where((s) => !services.contains(s)).toList(),
                onAdd: (s) {
                  final updated = List<String>.from(services)..add(s);
                  _patchProfile(context, ref, ph, {'services': updated});
                },
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
        ]);
      },
    );
  }

  void _showEditDelivery(BuildContext context, WidgetRef ref, Map ph) {
    final radiusCtrl = TextEditingController(text: '${ph['delivery_radius_km'] ?? 0}');
    final feeCtrl = TextEditingController(text: '${ph['delivery_fee'] ?? 0}');
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Delivery Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            _fieldBox(context, 'Delivery Radius (km)', radiusCtrl, keyboard: TextInputType.number),
            const SizedBox(height: 12),
            _fieldBox(context, 'Delivery Fee (KSH)', feeCtrl, keyboard: TextInputType.number),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: () async {
                await _patchProfile(context, ref, ph, {
                  'delivery_radius_km': double.tryParse(radiusCtrl.text) ?? 0,
                  'delivery_fee': double.tryParse(feeCtrl.text) ?? 0,
                });
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            )),
          ]),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 4 — INSURANCE
// ═══════════════════════════════════════════════════════════════════════════
class _InsuranceTab extends StatelessWidget {
  const _InsuranceTab({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final profile = ref.watch(_profileProvider);

    return profile.when(
      loading: () => const LoadingShimmer(),
      error: (_, __) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_profileProvider)),
      data: (d) {
        final ph = d['pharmacy'] as Map? ?? {};
        final accepts = ph['accepts_insurance'] == true;
        final providers = List<String>.from((ph['insurance_providers'] as List?) ?? []);

        return ListView(padding: const EdgeInsets.all(16), children: [
          // Toggle
          Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accepts ? const Color(0xFF10B981).withValues(alpha: 0.3) : cs.outlineVariant.withValues(alpha: 0.5))),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                secondary: Icon(accepts ? Icons.verified_rounded : Icons.cancel_rounded,
                  color: accepts ? const Color(0xFF10B981) : cs.onSurfaceVariant),
                title: const Text('Accept Insurance', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(accepts ? 'Patients can use insurance' : 'Insurance not accepted',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                value: accepts,
                onChanged: (v) => _patchProfile(context, ref, ph, {'accepts_insurance': v}),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 16),

          if (accepts) _SectionCard(
            title: 'Insurance Providers (${providers.length})', icon: Icons.health_and_safety_rounded,
            children: [
              if (providers.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No providers configured', style: TextStyle(color: Colors.grey, fontSize: 13))),
              Wrap(spacing: 6, runSpacing: 6, children: providers.map((p) => Chip(
                label: Text(p, style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close_rounded, size: 14),
                onDeleted: () {
                  final updated = List<String>.from(providers)..remove(p);
                  _patchProfile(context, ref, ph, {'insurance_providers': updated});
                },
              )).toList()),
              const SizedBox(height: 12),
              _AddChipButton(
                suggestions: _defaultInsurers.where((i) => !providers.contains(i)).toList(),
                onAdd: (p) {
                  final updated = List<String>.from(providers)..add(p);
                  _patchProfile(context, ref, ph, {'insurance_providers': updated});
                },
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
        ]);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 5 — SECURITY
// ═══════════════════════════════════════════════════════════════════════════
class _SecurityTab extends StatelessWidget {
  const _SecurityTab({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Account info
      _SectionCard(title: 'Account', icon: Icons.person_rounded, children: [
        _InfoRow(icon: Icons.email_rounded, label: 'Email', value: auth.user?.email ?? '-'),
        _InfoRow(icon: Icons.phone_rounded, label: 'Phone', value: auth.user?.phone ?? '-'),
        _InfoRow(icon: Icons.badge_rounded, label: 'Role', value: (auth.user?.role ?? '-').replaceAll('_', ' ')),
      ]).animate().fadeIn(duration: 400.ms),
      const SizedBox(height: 16),

      // Actions
      Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
          child: Column(children: [
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.lock_rounded, size: 18, color: Color(0xFF3B82F6))),
              title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Update your account password', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showChangePassword(context, ref),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.pin_rounded, size: 18, color: Color(0xFFF59E0B))),
              title: const Text('Regenerate PIN', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Current: ${auth.user?.pin ?? 'Not set'}', style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _regeneratePin(context, ref),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.logout_rounded, size: 18, color: Colors.red)),
              title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
              subtitle: const Text('Sign out from this device', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final ok = await _confirm(context, 'Sign Out?', 'You will need to log in again.');
                if (ok) ref.read(authProvider.notifier).logout();
              },
            ),
          ]),
        ),
      ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
    ]);
  }

  void _regeneratePin(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(context, 'Regenerate PIN?', 'Your current PIN will be replaced with a new one.');
    if (!ok || !context.mounted) return;
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/auth/regenerate-pin/');
      ref.read(authProvider.notifier).restore();
      if (context.mounted) _snack(context, 'New PIN: ${res.data?['pin'] ?? 'generated'}', const Color(0xFF10B981));
    } catch (e) { if (context.mounted) _snack(context, 'Failed to regenerate PIN', Colors.red); }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 6 — ABOUT
// ═══════════════════════════════════════════════════════════════════════════
class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Logo / brand
      Center(child: Column(children: [
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(24)),
          child: Icon(Icons.local_pharmacy_rounded, size: 48, color: cs.primary)),
        const SizedBox(height: 16),
        const Text('AdhereMed', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Healthcare Management Platform', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Text('v1.0.0', style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary, fontSize: 12))),
      ])).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
      const SizedBox(height: 20),

      // Description
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.primary.withValues(alpha: 0.1)),
        ),
        child: Column(children: [
          Text(
            'AdhereMed is a comprehensive healthcare management system that seamlessly connects every network in the healthcare ecosystem — patients, doctors, pharmacies, hospitals, laboratories, radiology centers, homecare providers, and insurance companies — all in one unified platform.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
            _EcoBadge(icon: Icons.personal_injury_rounded, label: 'Patients'),
            _EcoBadge(icon: Icons.medical_services_rounded, label: 'Doctors'),
            _EcoBadge(icon: Icons.local_pharmacy_rounded, label: 'Pharmacy'),
            _EcoBadge(icon: Icons.local_hospital_rounded, label: 'Hospitals'),
            _EcoBadge(icon: Icons.science_rounded, label: 'Laboratory'),
            _EcoBadge(icon: Icons.monitor_heart_rounded, label: 'Radiology'),
            _EcoBadge(icon: Icons.home_rounded, label: 'Homecare'),
            _EcoBadge(icon: Icons.health_and_safety_rounded, label: 'Insurance'),
          ]),
        ]),
      ).animate().fadeIn(duration: 400.ms, delay: 80.ms),
      const SizedBox(height: 20),

      _SectionCard(title: 'System Info', icon: Icons.info_rounded, children: [
        _InfoRow(icon: Icons.business_rounded, label: 'Tenant', value: auth.user?.tenantName ?? '-'),
        _InfoRow(icon: Icons.category_rounded, label: 'Type', value: (auth.user?.tenantType ?? '-').replaceAll('_', ' ')),
        _InfoRow(icon: Icons.dns_rounded, label: 'Schema', value: auth.user?.tenantSchema ?? '-'),
        _InfoRow(icon: Icons.calendar_today_rounded, label: 'Build', value: 'May 2026'),
      ]).animate().fadeIn(duration: 400.ms, delay: 150.ms),
      const SizedBox(height: 16),

      // Quick links
      Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
          child: Column(children: [
            ListTile(leading: const Icon(Icons.store_rounded), title: const Text('Branches'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/branches')),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(leading: const Icon(Icons.people_rounded), title: const Text('Staff'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/staff')),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(leading: const Icon(Icons.notifications_rounded), title: const Text('Notifications'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/alerts')),
          ]),
        ),
      ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
      const SizedBox(height: 40),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  EDIT PROFILE SHEET
// ═══════════════════════════════════════════════════════════════════════════
void _showEditProfile(BuildContext context, WidgetRef ref) {
  final auth = ref.read(authProvider);
  final fnCtrl = TextEditingController(text: auth.user?.firstName ?? '');
  final lnCtrl = TextEditingController(text: auth.user?.lastName ?? '');
  final phoneCtrl = TextEditingController(text: auth.user?.phone ?? '');
  final cs = Theme.of(context).colorScheme;

  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        const Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _fieldBox(context, 'First Name', fnCtrl)),
          const SizedBox(width: 12),
          Expanded(child: _fieldBox(context, 'Last Name', lnCtrl)),
        ]),
        const SizedBox(height: 12),
        _fieldBox(context, 'Phone', phoneCtrl, keyboard: TextInputType.phone),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: () async {
            try {
              await ref.read(dioProvider).put('/auth/me/', data: {
                'first_name': fnCtrl.text.trim(),
                'last_name': lnCtrl.text.trim(),
                'phone': phoneCtrl.text.trim(),
              });
              ref.read(authProvider.notifier).restore();
              ref.invalidate(_profileProvider);
              if (context.mounted) { Navigator.pop(context); _snack(context, 'Profile updated', const Color(0xFF10B981)); }
            } catch (e) { if (context.mounted) _snack(context, 'Failed to update', Colors.red); }
          },
          icon: const Icon(Icons.save_rounded, size: 18),
          label: const Text('Save'),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  EDIT PHARMACY SHEET
// ═══════════════════════════════════════════════════════════════════════════
void _showEditPharmacy(BuildContext context, WidgetRef ref, Map ph) {
  final nameCtrl = TextEditingController(text: ph['name'] ?? '');
  final licenseCtrl = TextEditingController(text: ph['license_number'] ?? '');
  final descCtrl = TextEditingController(text: ph['description'] ?? '');
  final cs = Theme.of(context).colorScheme;

  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7, maxChildSize: 0.9, minChildSize: 0.4,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: Column(children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.local_pharmacy_rounded, size: 22),
              const SizedBox(width: 10),
              const Expanded(child: Text('Edit Pharmacy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 12), const Divider(height: 1),
          ])),
          Expanded(child: ListView(controller: scrollCtrl, padding: const EdgeInsets.all(20), children: [
            _fieldBox(context, 'Pharmacy Name *', nameCtrl),
            const SizedBox(height: 14),
            _fieldBox(context, 'License Number', licenseCtrl),
            const SizedBox(height: 14),
            _fieldBox(context, 'Description', descCtrl, maxLines: 3),
            const SizedBox(height: 14),
            // Logo upload
            OutlinedButton.icon(
              onPressed: () => _uploadLogo(context, ref, ph),
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text('Upload Logo'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                await _patchProfile(context, ref, ph, {
                  'name': nameCtrl.text.trim(),
                  'license_number': licenseCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save Changes'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 20),
          ])),
        ]),
      ),
    ),
  );
}

void _uploadLogo(BuildContext context, WidgetRef ref, Map ph) async {
  try {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (img == null) return;
    final formData = FormData.fromMap({'logo': await MultipartFile.fromFile(img.path, filename: 'logo.jpg')});
    final id = ph['id'];
    await ref.read(dioProvider).post('/pharmacy-profile/profile/$id/upload-logo/', data: formData);
    ref.invalidate(_profileProvider);
    if (context.mounted) _snack(context, 'Logo uploaded', const Color(0xFF10B981));
  } catch (e) { if (context.mounted) _snack(context, 'Upload failed', Colors.red); }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CHANGE PASSWORD DIALOG
// ═══════════════════════════════════════════════════════════════════════════
void _showChangePassword(BuildContext context, WidgetRef ref) {
  final oldCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  final cs = Theme.of(context).colorScheme;

  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => StatefulBuilder(builder: (ctx, setState) {
      bool obscureOld = true, obscureNew = true;
      return Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.lock_rounded, color: Color(0xFF3B82F6), size: 22)),
            const SizedBox(width: 12),
            const Text('Change Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 20),
          _fieldBox(context, 'Current Password', oldCtrl, obscure: true),
          const SizedBox(height: 12),
          _fieldBox(context, 'New Password', newCtrl, obscure: true),
          const SizedBox(height: 12),
          _fieldBox(context, 'Confirm Password', confirmCtrl, obscure: true),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) { _snack(context, 'Passwords do not match', Colors.orange); return; }
              if (newCtrl.text.length < 6) { _snack(context, 'Password too short', Colors.orange); return; }
              final ok = await ref.read(authProvider.notifier).changePassword(oldCtrl.text, newCtrl.text);
              if (ctx.mounted) {
                if (ok) { Navigator.pop(ctx); _snack(context, 'Password changed', const Color(0xFF10B981)); }
                else { _snack(context, 'Failed to change password', Colors.red); }
              }
            },
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Update Password'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
        ]),
      );
    }),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  PATCH HELPER
// ═══════════════════════════════════════════════════════════════════════════
Future<void> _patchProfile(BuildContext context, WidgetRef ref, Map ph, Map<String, dynamic> data) async {
  try {
    final id = ph['id'];
    if (id != null) {
      await ref.read(dioProvider).patch('/pharmacy-profile/profile/$id/', data: data);
    } else {
      await ref.read(dioProvider).post('/pharmacy-profile/profile/', data: {...Map<String, dynamic>.from(ph), ...data});
    }
    ref.invalidate(_profileProvider);
    if (context.mounted) _snack(context, 'Saved', const Color(0xFF10B981));
  } catch (e) { if (context.mounted) _snack(context, 'Failed to save', Colors.red); }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════
Widget _fieldBox(BuildContext context, String label, TextEditingController ctrl,
    {int maxLines = 1, TextInputType? keyboard, bool obscure = false}) {
  final cs = Theme.of(context).colorScheme;
  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
    const SizedBox(height: 6),
    TextField(controller: ctrl, maxLines: maxLines, keyboardType: keyboard, obscureText: obscure,
      decoration: InputDecoration(isDense: true, filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
      style: const TextStyle(fontSize: 14)),
  ]);
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon; final String label; final String value;
  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
      Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: cs.primary)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ])),
    ]));
  }
}

class _EcoBadge extends StatelessWidget {
  const _EcoBadge({required this.icon, required this.label});
  final IconData icon; final String label;
  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: cs.primary),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurface)),
      ]),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.children});
  final String title; final IconData icon; final List<Widget> children;
  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ]),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.onTap});
  final String label; final VoidCallback onTap;
  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary))),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.time, required this.onTap});
  final String time; final VoidCallback onTap;
  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
        child: Text(time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
    );
  }
}

class _AddChipButton extends StatelessWidget {
  const _AddChipButton({required this.suggestions, required this.onAdd});
  final List<String> suggestions; final void Function(String) onAdd;
  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final customCtrl = TextEditingController();
    return Row(children: [
      Expanded(child: Autocomplete<String>(
        optionsBuilder: (v) => suggestions.where((s) => s.toLowerCase().contains(v.text.toLowerCase())),
        onSelected: onAdd,
        fieldViewBuilder: (ctx, ctrl, focus, onSubmit) {
          customCtrl.text = ctrl.text;
          return TextField(controller: ctrl, focusNode: focus,
            decoration: InputDecoration(hintText: 'Add...', isDense: true, filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5), prefixIcon: const Icon(Icons.add_rounded, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
            style: const TextStyle(fontSize: 13),
            onSubmitted: (v) { if (v.trim().isNotEmpty) onAdd(v.trim()); ctrl.clear(); });
        },
      )),
    ]);
  }
}

Future<bool> _confirm(BuildContext ctx, String t, String c) async =>
  await showDialog<bool>(context: ctx, builder: (d) => AlertDialog(title: Text(t), content: Text(c), actions: [
    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
    FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Confirm'))])) ?? false;

void _snack(BuildContext c, String m, Color co) =>
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, backgroundColor: co));
