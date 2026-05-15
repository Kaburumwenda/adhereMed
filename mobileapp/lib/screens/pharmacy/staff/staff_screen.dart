import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

// ─── Providers ──────────────────────────────────────
final _searchProvider = StateProvider<String>((ref) => '');
final _roleFilterProvider = StateProvider<String>((ref) => '');
final _availFilterProvider = StateProvider<String>((ref) => '');

final _staffProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final params = <String, dynamic>{'page_size': 200};
  final search = ref.watch(_searchProvider);
  final role = ref.watch(_roleFilterProvider);
  final avail = ref.watch(_availFilterProvider);
  if (search.isNotEmpty) params['search'] = search;
  if (role.isNotEmpty) params['user__role'] = role;
  if (avail.isNotEmpty) params['is_available'] = avail;
  final res = await dio.get('/staff/', queryParameters: params);
  return (res.data['results'] as List?) ?? [];
});

final _specProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/staff/specializations/');
  final d = res.data;
  return (d is List ? d : (d['results'] as List?) ?? []);
});

final _branchesProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/pharmacy-profile/branches/');
  final d = res.data;
  return (d is List ? d : (d['results'] as List?) ?? []);
});

const _roles = [
  ('pharmacist', 'Pharmacist'),
  ('pharmacy_tech', 'Pharmacy Tech'),
  ('cashier', 'Cashier'),
  ('lab_tech', 'Lab Tech'),
  ('radiologist', 'Radiologist'),
  ('receptionist', 'Receptionist'),
  ('doctor', 'Doctor'),
  ('clinical_officer', 'Clinical Officer'),
  ('nurse', 'Nurse'),
  ('midwife', 'Midwife'),
];

// ─── Main Screen ────────────────────────────────────
class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});
  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() => _currentTab = _tabCtrl.index);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Performance',
            onPressed: () => context.push('/staff/performance'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(_staffProvider);
              ref.invalidate(_specProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          dividerHeight: 0,
          tabs: const [
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.people_rounded, size: 16), SizedBox(width: 6), Text('Team')])),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.local_hospital_rounded, size: 16), SizedBox(width: 6), Text('Specializations')])),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _currentTab == 0 ? _showStaffDialog(context, ref) : _showSpecDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text(_currentTab == 0 ? 'Add Staff' : 'Add Specialization'),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _TeamTab(searchCtrl: _searchCtrl),
          const _SpecializationsTab(),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// TEAM TAB
// ════════════════════════════════════════════════════
class _TeamTab extends ConsumerWidget {
  final TextEditingController searchCtrl;
  const _TeamTab({required this.searchCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staff = ref.watch(_staffProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(children: [
      // Search
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        child: TextField(
          controller: searchCtrl,
          decoration: InputDecoration(
            hintText: 'Search staff...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: searchCtrl.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () { searchCtrl.clear(); ref.read(_searchProvider.notifier).state = ''; })
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant)),
          ),
          onChanged: (v) => ref.read(_searchProvider.notifier).state = v,
        ),
      ),

      // Filter chips
      SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          children: [
            _FilterChip(
              label: 'Role',
              value: ref.watch(_roleFilterProvider),
              options: _roles,
              onChanged: (v) => ref.read(_roleFilterProvider.notifier).state = v,
            ),
            const SizedBox(width: 6),
            _FilterChip(
              label: 'Availability',
              value: ref.watch(_availFilterProvider),
              options: const [('true', 'Available'), ('false', 'Unavailable')],
              onChanged: (v) => ref.read(_availFilterProvider.notifier).state = v,
            ),
          ],
        ),
      ),

      // KPIs
      staff.whenOrNull(data: (items) {
        final total = items.length;
        final byRole = <String, int>{};
        for (final s in items) {
          final r = '${s['user_role'] ?? ''}';
          byRole[r] = (byRole[r] ?? 0) + 1;
        }
        return SizedBox(
          height: 62,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            children: [
              _MiniKPI(label: 'Total', value: '$total', color: const Color(0xFF6366F1)),
              _MiniKPI(label: 'Pharmacists', value: '${byRole['pharmacist'] ?? 0}', color: const Color(0xFF22C55E)),
              _MiniKPI(label: 'Pharm Tech', value: '${byRole['pharmacy_tech'] ?? 0}', color: const Color(0xFF3B82F6)),
              _MiniKPI(label: 'Cashiers', value: '${byRole['cashier'] ?? 0}', color: const Color(0xFFF59E0B)),
              _MiniKPI(label: 'Available', value: '${items.where((s) => s['is_available'] == true).length}', color: const Color(0xFF14B8A6)),
            ],
          ),
        );
      }) ?? const SizedBox.shrink(),

      // List
      Expanded(child: staff.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorRetry(message: 'Failed to load staff', onRetry: () => ref.invalidate(_staffProvider)),
        data: (items) {
          if (items.isEmpty) return const EmptyState(icon: Icons.people_rounded, title: 'No staff found');
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_staffProvider),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
              itemCount: items.length,
              itemBuilder: (_, i) => _StaffCard(staff: items[i], index: i).animate().fadeIn(delay: (30 * i).clamp(0, 300).ms, duration: 250.ms),
            ),
          );
        },
      )),
    ]);
  }
}

// ════════════════════════════════════════════════════
// STAFF CARD
// ════════════════════════════════════════════════════
class _StaffCard extends ConsumerWidget {
  final Map<String, dynamic> staff;
  final int index;
  const _StaffCard({required this.staff, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final name = '${staff['user_name'] ?? ''}'.trim();
    final initials = name.split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    final role = '${staff['user_role'] ?? ''}'.replaceAll('_', ' ');
    final email = '${staff['user_email'] ?? ''}';
    final phone = '${staff['user_phone'] ?? ''}';
    final spec = '${staff['specialization_name'] ?? ''}';
    final branch = '${staff['branch_name'] ?? ''}';
    final available = staff['is_available'] == true;
    final active = staff['is_user_active'] == true;
    final license = '${staff['license_number'] ?? ''}';
    final qual = '${staff['qualification'] ?? ''}';
    final yrs = staff['years_of_experience'];

    final roleColor = _roleColor(staff['user_role']);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.12))),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showStaffDetail(context, ref, staff),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Avatar
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [roleColor.withValues(alpha: 0.15), roleColor.withValues(alpha: 0.05)]),
              ),
              child: Center(child: Text(initials.isEmpty ? '?' : initials, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: roleColor))),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name.isNotEmpty ? name : 'Staff #${staff['id']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (!active)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: const Text('Inactive', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                  ),
              ]),
              const SizedBox(height: 4),
              if (email.isNotEmpty)
                Text(email, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _RoleChip(role, roleColor),
                if (spec.isNotEmpty) _TinyChip(spec, const Color(0xFF8B5CF6)),
                if (branch.isNotEmpty) _TinyChip(branch, const Color(0xFF06B6D4)),
                if (phone.isNotEmpty) _TinyChip(phone, Colors.grey),
              ]),
              if (license.isNotEmpty || qual.isNotEmpty || (yrs != null && yrs > 0)) ...[
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 2, children: [
                  if (license.isNotEmpty) _TinyChip('Lic: $license', Colors.grey),
                  if (qual.isNotEmpty) _TinyChip(qual, Colors.grey),
                  if (yrs != null && yrs > 0) _TinyChip('${yrs}y exp', Colors.grey),
                ]),
              ],
            ])),

            // Availability toggle
            Column(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: () => _toggleAvailability(context, ref, staff),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: available ? const Color(0xFF22C55E).withValues(alpha: 0.12) : const Color(0xFFEF4444).withValues(alpha: 0.1),
                  ),
                  child: Icon(available ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 20, color: available ? const Color(0xFF22C55E) : const Color(0xFFEF4444)),
                ),
              ),
              Text(available ? 'Active' : 'Away', style: TextStyle(fontSize: 8, color: cs.onSurfaceVariant)),
            ]),
          ]),
        ),
      ),
    );
  }

  void _toggleAvailability(BuildContext context, WidgetRef ref, Map<String, dynamic> s) async {
    final dio = ref.read(dioProvider);
    final newVal = !(s['is_available'] == true);
    try {
      await dio.patch('/staff/${s['id']}/', data: {'is_available': newVal});
      ref.invalidate(_staffProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${s['user_name']} marked ${newVal ? 'available' : 'unavailable'}'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update'), behavior: SnackBarBehavior.floating));
      }
    }
  }
}

Color _roleColor(dynamic role) {
  return switch ('$role') {
    'pharmacist' => const Color(0xFF22C55E),
    'pharmacy_tech' => const Color(0xFF3B82F6),
    'cashier' => const Color(0xFFF59E0B),
    'lab_tech' => const Color(0xFF8B5CF6),
    'radiologist' => const Color(0xFF06B6D4),
    'doctor' => const Color(0xFFEF4444),
    'clinical_officer' => const Color(0xFFEC4899),
    'nurse' => const Color(0xFF14B8A6),
    _ => const Color(0xFF6B7280),
  };
}

// ════════════════════════════════════════════════════
// STAFF DETAIL BOTTOM SHEET
// ════════════════════════════════════════════════════
void _showStaffDetail(BuildContext context, WidgetRef ref, Map<String, dynamic> s) {
  final cs = Theme.of(context).colorScheme;
  final name = '${s['user_name'] ?? ''}'.trim();
  final role = '${s['user_role'] ?? ''}'.replaceAll('_', ' ');
  final roleColor = _roleColor(s['user_role']);
  final schedule = s['schedule'] as Map<String, dynamic>?;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      builder: (ctx, scrollCtrl) => ListView(controller: scrollCtrl, padding: const EdgeInsets.all(20), children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),

        // Header
        Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle, color: roleColor.withValues(alpha: 0.12)),
            child: Center(child: Text(
              name.split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: roleColor),
            )),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            _RoleChip(role, roleColor),
          ])),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) {
              Navigator.pop(ctx);
              if (v == 'edit') _showStaffDialog(context, ref, staff: s);
              if (v == 'delete') _confirmDelete(context, ref, s);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 18), SizedBox(width: 8), Text('Edit')])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: Color(0xFFEF4444)), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Color(0xFFEF4444)))])),
            ],
          ),
        ]),

        const SizedBox(height: 20),

        // Details
        _DetailRow(Icons.email_rounded, 'Email', '${s['user_email'] ?? '—'}'),
        _DetailRow(Icons.phone_rounded, 'Phone', '${s['user_phone'] ?? '—'}'),
        _DetailRow(Icons.local_hospital_rounded, 'Specialization', '${s['specialization_name'] ?? '—'}'),
        _DetailRow(Icons.store_rounded, 'Branch', '${s['branch_name'] ?? '—'}'),
        _DetailRow(Icons.badge_rounded, 'License', '${s['license_number'] ?? '—'}'),
        _DetailRow(Icons.school_rounded, 'Qualification', '${s['qualification'] ?? '—'}'),
        _DetailRow(Icons.work_rounded, 'Experience', s['years_of_experience'] != null ? '${s['years_of_experience']} years' : '—'),
        _DetailRow(Icons.circle, 'Available', s['is_available'] == true ? 'Yes' : 'No'),
        _DetailRow(Icons.person_rounded, 'Account Active', s['is_user_active'] == true ? 'Yes' : 'No'),

        // Schedule
        if (schedule != null && schedule.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Weekly Schedule', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface)),
          const SizedBox(height: 8),
          ...['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].map((day) {
            final val = schedule[day.toLowerCase()] ?? schedule[day] ?? '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(day, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                Text(val.toString().isNotEmpty ? val.toString() : '—', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: val.toString().isNotEmpty ? cs.onSurface : cs.onSurfaceVariant)),
              ]),
            );
          }),
        ],
      ]),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════
// CREATE / EDIT STAFF DIALOG
// ════════════════════════════════════════════════════
void _showStaffDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? staff}) {
  final isEdit = staff != null;
  final formKey = GlobalKey<FormState>();
  final firstName = TextEditingController(text: isEdit ? '${staff['user_name'] ?? ''}'.split(' ').first : '');
  final lastName = TextEditingController(text: isEdit ? '${staff['user_name'] ?? ''}'.split(' ').skip(1).join(' ') : '');
  final email = TextEditingController(text: isEdit ? '${staff['user_email'] ?? ''}' : '');
  final phone = TextEditingController(text: isEdit ? '${staff['user_phone'] ?? ''}' : '');
  final license = TextEditingController(text: isEdit ? '${staff['license_number'] ?? ''}' : '');
  final qualification = TextEditingController(text: isEdit ? '${staff['qualification'] ?? ''}' : '');
  final experience = TextEditingController(text: isEdit && staff['years_of_experience'] != null ? '${staff['years_of_experience']}' : '');
  final password = TextEditingController();

  String selectedRole = isEdit ? '${staff['user_role'] ?? 'cashier'}' : 'cashier';
  int? selectedSpec = isEdit ? staff['specialization'] : null;
  int? selectedBranch = isEdit ? staff['branch'] : null;
  bool isAvailable = isEdit ? (staff['is_available'] == true) : true;
  bool isUserActive = isEdit ? (staff['is_user_active'] == true) : true;
  bool saving = false;

  // Schedule
  final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  final schedCtrls = <String, TextEditingController>{};
  for (final d in days) {
    final existing = isEdit && staff['schedule'] is Map ? (staff['schedule'] as Map)[d] ?? '' : '';
    schedCtrls[d] = TextEditingController(text: '$existing');
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => StatefulBuilder(builder: (ctx, setState) {
      final cs = Theme.of(ctx).colorScheme;
      final specs = ref.read(_specProvider).valueOrNull ?? [];
      final branches = ref.read(_branchesProvider).valueOrNull ?? [];

      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Form(
          key: formKey,
          child: ListView(controller: scrollCtrl, padding: const EdgeInsets.all(20), children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Text(isEdit ? 'Edit Staff' : 'Add Staff Member', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            // Name row
            Row(children: [
              Expanded(child: TextFormField(
                controller: firstName,
                decoration: const InputDecoration(labelText: 'First Name', isDense: true),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                controller: lastName,
                decoration: const InputDecoration(labelText: 'Last Name', isDense: true),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              )),
            ]),
            const SizedBox(height: 12),

            TextFormField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Email', isDense: true, prefixIcon: Icon(Icons.email_rounded, size: 18)),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'Phone', isDense: true, prefixIcon: Icon(Icons.phone_rounded, size: 18)),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            // Role dropdown
            DropdownButtonFormField<String>(
              value: selectedRole,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Role', isDense: true, prefixIcon: Icon(Icons.badge_rounded, size: 18)),
              items: _roles.map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => selectedRole = v ?? 'cashier'),
            ),
            const SizedBox(height: 12),

            // Specialization
            if (specs.isNotEmpty)
              DropdownButtonFormField<int?>(
                value: selectedSpec,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Specialization', isDense: true, prefixIcon: Icon(Icons.local_hospital_rounded, size: 18)),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('None')),
                  ...specs.map((s) => DropdownMenuItem<int?>(value: s['id'], child: Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) => setState(() => selectedSpec = v),
              ),
            if (specs.isNotEmpty) const SizedBox(height: 12),

            // Branch
            if (branches.isNotEmpty)
              DropdownButtonFormField<int?>(
                value: selectedBranch,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Branch', isDense: true, prefixIcon: Icon(Icons.store_rounded, size: 18)),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('None')),
                  ...branches.map((b) => DropdownMenuItem<int?>(value: b['id'], child: Text('${b['name']}', maxLines: 1, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (v) => setState(() => selectedBranch = v),
              ),
            if (branches.isNotEmpty) const SizedBox(height: 12),

            // License, Qualification, Experience
            TextFormField(controller: license, decoration: const InputDecoration(labelText: 'License Number', isDense: true)),
            const SizedBox(height: 12),
            TextFormField(controller: qualification, decoration: const InputDecoration(labelText: 'Qualification', isDense: true)),
            const SizedBox(height: 12),
            TextFormField(
              controller: experience,
              decoration: const InputDecoration(labelText: 'Years of Experience', isDense: true),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            // Password
            TextFormField(
              controller: password,
              decoration: InputDecoration(
                labelText: isEdit ? 'New Password (leave blank to keep)' : 'Password',
                isDense: true,
                prefixIcon: const Icon(Icons.lock_rounded, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.casino_rounded, size: 18),
                  tooltip: 'Generate password',
                  onPressed: () {
                    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$';
                    final rng = Random.secure();
                    password.text = List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
                  },
                ),
              ),
              obscureText: true,
              validator: (v) => !isEdit && (v == null || v.length < 8) ? 'Min 8 characters' : null,
            ),
            const SizedBox(height: 16),

            // Toggles
            SwitchListTile(
              title: const Text('Available', style: TextStyle(fontSize: 14)),
              value: isAvailable,
              onChanged: (v) => setState(() => isAvailable = v),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            if (isEdit)
              SwitchListTile(
                title: const Text('Account Active', style: TextStyle(fontSize: 14)),
                value: isUserActive,
                onChanged: (v) => setState(() => isUserActive = v),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),

            // Schedule
            const SizedBox(height: 12),
            Text('Weekly Schedule', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            ...days.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                SizedBox(width: 80, child: Text(d[0].toUpperCase() + d.substring(1), style: const TextStyle(fontSize: 12))),
                Expanded(child: TextFormField(
                  controller: schedCtrls[d],
                  decoration: InputDecoration(hintText: 'e.g. 08:00 – 17:00', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  style: const TextStyle(fontSize: 12),
                )),
              ]),
            )),

            const SizedBox(height: 20),

            // Submit
            FilledButton.icon(
              onPressed: saving ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setState(() => saving = true);
                try {
                  final dio = ref.read(dioProvider);
                  final sched = <String, String>{};
                  for (final d in days) {
                    if (schedCtrls[d]!.text.isNotEmpty) sched[d] = schedCtrls[d]!.text;
                  }

                  if (isEdit) {
                    final body = <String, dynamic>{
                      'first_name': firstName.text,
                      'last_name': lastName.text,
                      'email': email.text,
                      'phone': phone.text,
                      'role': selectedRole,
                      'specialization': selectedSpec,
                      'license_number': license.text,
                      'qualification': qualification.text,
                      'years_of_experience': int.tryParse(experience.text) ?? 0,
                      'is_available': isAvailable,
                      'is_user_active': isUserActive,
                      'branch_id': selectedBranch,
                      'schedule': sched,
                    };
                    if (password.text.isNotEmpty) body['password'] = password.text;
                    await dio.patch('/staff/${staff['id']}/', data: body);
                  } else {
                    await dio.post('/staff/', data: {
                      'first_name': firstName.text,
                      'last_name': lastName.text,
                      'email': email.text,
                      'phone': phone.text,
                      'role': selectedRole,
                      'password': password.text,
                      'specialization': selectedSpec,
                      'license_number': license.text,
                      'qualification': qualification.text,
                      'years_of_experience': int.tryParse(experience.text) ?? 0,
                      'is_available': isAvailable,
                      'branch_id': selectedBranch,
                    });
                  }
                  ref.invalidate(_staffProvider);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(isEdit ? 'Staff updated' : 'Staff created'), behavior: SnackBarBehavior.floating));
                  }
                } catch (e) {
                  setState(() => saving = false);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
                  }
                }
              },
              icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(isEdit ? Icons.save_rounded : Icons.add_rounded),
              label: Text(isEdit ? 'Save Changes' : 'Create Staff'),
            ),
          ]),
        ),
      );
    }),
  );
}

void _confirmDelete(BuildContext context, WidgetRef ref, Map<String, dynamic> s) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete Staff'),
      content: Text('Remove ${s['user_name']}? This action cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
          onPressed: () async {
            Navigator.pop(context);
            try {
              await ref.read(dioProvider).delete('/staff/${s['id']}/');
              ref.invalidate(_staffProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff deleted'), behavior: SnackBarBehavior.floating));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
              }
            }
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════
// SPECIALIZATIONS TAB
// ════════════════════════════════════════════════════
class _SpecializationsTab extends ConsumerWidget {
  const _SpecializationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_specProvider);
    final cs = Theme.of(context).colorScheme;

    return data.when(
      loading: () => const LoadingShimmer(),
      error: (e, _) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_specProvider)),
      data: (items) {
        if (items.isEmpty) return const EmptyState(icon: Icons.local_hospital_rounded, title: 'No specializations', subtitle: 'Add specializations for staff members');
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_specProvider),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final s = items[i];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.1))),
                child: ListTile(
                  leading: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF8B5CF6).withValues(alpha: 0.1)),
                    child: const Icon(Icons.local_hospital_rounded, size: 18, color: Color(0xFF8B5CF6)),
                  ),
                  title: Text('${s['name']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: s['description'] != null && '${s['description']}'.isNotEmpty
                      ? Text('${s['description']}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: s['is_active'] == true ? const Color(0xFF22C55E).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(s['is_active'] == true ? 'Active' : 'Inactive', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: s['is_active'] == true ? const Color(0xFF22C55E) : const Color(0xFFEF4444))),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 18),
                      onSelected: (v) {
                        if (v == 'edit') _showSpecDialog(context, ref, spec: s);
                        if (v == 'toggle') _toggleSpec(context, ref, s);
                        if (v == 'delete') _deleteSpec(context, ref, s);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 16), SizedBox(width: 8), Text('Edit')])),
                        PopupMenuItem(value: 'toggle', child: Row(children: [Icon(s['is_active'] == true ? Icons.block_rounded : Icons.check_circle_rounded, size: 16), const SizedBox(width: 8), Text(s['is_active'] == true ? 'Deactivate' : 'Activate')])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 16, color: Color(0xFFEF4444)), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Color(0xFFEF4444)))])),
                      ],
                    ),
                  ]),
                ),
              ).animate().fadeIn(delay: (30 * i).ms, duration: 250.ms);
            },
          ),
        );
      },
    );
  }

  void _toggleSpec(BuildContext context, WidgetRef ref, Map<String, dynamic> s) async {
    try {
      await ref.read(dioProvider).patch('/staff/specializations/${s['id']}/', data: {'is_active': !(s['is_active'] == true)});
      ref.invalidate(_specProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
    }
  }

  void _deleteSpec(BuildContext context, WidgetRef ref, Map<String, dynamic> s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Specialization'),
        content: Text('Remove "${s['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(dioProvider).delete('/staff/specializations/${s['id']}/');
                ref.invalidate(_specProvider);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

void _showSpecDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? spec}) {
  final isEdit = spec != null;
  final nameCtrl = TextEditingController(text: isEdit ? '${spec['name'] ?? ''}' : '');
  final descCtrl = TextEditingController(text: isEdit ? '${spec['description'] ?? ''}' : '');
  bool isActive = isEdit ? (spec['is_active'] == true) : true;
  bool saving = false;

  showDialog(
    context: context,
    builder: (_) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
      title: Text(isEdit ? 'Edit Specialization' : 'Add Specialization'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', isDense: true)),
        const SizedBox(height: 12),
        TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', isDense: true), maxLines: 2),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Active', style: TextStyle(fontSize: 14)),
          value: isActive,
          onChanged: (v) => setState(() => isActive = v),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: saving ? null : () async {
            if (nameCtrl.text.isEmpty) return;
            setState(() => saving = true);
            try {
              final dio = ref.read(dioProvider);
              final body = {'name': nameCtrl.text, 'description': descCtrl.text, 'is_active': isActive};
              if (isEdit) {
                await dio.patch('/staff/specializations/${spec['id']}/', data: body);
              } else {
                await dio.post('/staff/specializations/', data: body);
              }
              ref.invalidate(_specProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              setState(() => saving = false);
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
            }
          },
          child: Text(saving ? 'Saving...' : (isEdit ? 'Save' : 'Create')),
        ),
      ],
    )),
  );
}

// ════════════════════════════════════════════════════
// SHARED WIDGETS
// ════════════════════════════════════════════════════
class _FilterChip extends StatelessWidget {
  final String label, value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;
  const _FilterChip({required this.label, required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = value.isNotEmpty;
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: Text('Filter by $label', style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: TextButton(onPressed: () { onChanged(''); Navigator.pop(context); }, child: const Text('Clear')),
            ),
            ...options.map((o) => ListTile(
              title: Text(o.$2),
              trailing: value == o.$1 ? const Icon(Icons.check_rounded, color: Color(0xFF6366F1)) : null,
              onTap: () { onChanged(o.$1); Navigator.pop(context); },
            )),
            const SizedBox(height: 12),
          ])),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF6366F1).withValues(alpha: 0.1) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? const Color(0xFF6366F1).withValues(alpha: 0.3) : cs.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(active ? options.firstWhere((o) => o.$1 == value, orElse: () => ('', label)).$2 : label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: active ? const Color(0xFF6366F1) : cs.onSurfaceVariant)),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down_rounded, size: 16, color: active ? const Color(0xFF6366F1) : cs.onSurfaceVariant),
        ]),
      ),
    );
  }
}

class _MiniKPI extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniKPI({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: color.withValues(alpha: 0.06),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7))),
    ]),
  );
}

class _RoleChip extends StatelessWidget {
  final String role;
  final Color color;
  const _RoleChip(this.role, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
    child: Text(role, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );
}

class _TinyChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TinyChip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w500)),
  );
}
