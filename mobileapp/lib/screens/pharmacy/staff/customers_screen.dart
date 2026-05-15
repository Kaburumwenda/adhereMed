import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════
final _searchProvider = StateProvider<String>((ref) => '');
final _tierFilterProvider = StateProvider<String>((ref) => '');

final _customersProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/pos/customers/', queryParameters: {'page_size': 300});
  final items = (res.data['results'] as List?) ?? (res.data is List ? res.data as List : []);
  final tier = ref.watch(_tierFilterProvider);
  final q = ref.watch(_searchProvider).toLowerCase();
  return items.where((c) {
    if (tier.isNotEmpty && c['loyalty_tier'] != tier) return false;
    if (q.isEmpty) return true;
    return '${c['name'] ?? ''}'.toLowerCase().contains(q) ||
      '${c['phone'] ?? ''}'.toLowerCase().contains(q) ||
      '${c['email'] ?? ''}'.toLowerCase().contains(q);
  }).toList();
});

// ═══════════════════════════════════════════════════════════════════════════
//  TIER HELPERS
// ═══════════════════════════════════════════════════════════════════════════
const _tiers = ['bronze', 'silver', 'gold', 'platinum'];
Color _tierColor(String t) => switch (t) {
  'bronze' => const Color(0xFFCD7F32),
  'silver' => const Color(0xFF94A3B8),
  'gold' => const Color(0xFFF59E0B),
  'platinum' => const Color(0xFF6366F1),
  _ => const Color(0xFF94A3B8),
};
IconData _tierIcon(String t) => switch (t) {
  'platinum' => Icons.diamond_rounded,
  'gold' => Icons.star_rounded,
  'silver' => Icons.workspace_premium_rounded,
  _ => Icons.loyalty_rounded,
};

String _fmtMoney(dynamic v) {
  if (v == null) return '0.00';
  final n = double.tryParse(v.toString()) ?? 0;
  return NumberFormat('#,##0.00').format(n);
}

// ═══════════════════════════════════════════════════════════════════════════
//  SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});
  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  Timer? _debounce;
  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = ref.watch(_customersProvider);
    final tierFilter = ref.watch(_tierFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customers', style: TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('New Customer'),
      ),
      body: Column(children: [
        // KPIs
        data.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            final active = items.where((c) => c['is_active'] != false).length;
            double totalPurchases = 0;
            int totalPoints = 0;
            for (final c in items) {
              totalPurchases += double.tryParse('${c['total_purchases'] ?? 0}') ?? 0;
              totalPoints += (c['loyalty_points'] as int?) ?? 0;
            }
            return _KpiRow(items: [
              _Kpi('Total', '${items.length}', const Color(0xFF6366F1)),
              _Kpi('Active', '$active', const Color(0xFF10B981)),
              _Kpi('Purchases', 'KSH ${NumberFormat.compact().format(totalPurchases)}', const Color(0xFF3B82F6)),
              _Kpi('Points', NumberFormat.compact().format(totalPoints), const Color(0xFFF59E0B)),
            ]);
          },
        ),
        // Search + filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(children: [
            Expanded(child: TextField(
              decoration: InputDecoration(hintText: 'Search customers...', prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true, filled: true, fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              style: const TextStyle(fontSize: 14),
              onChanged: (v) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 300), () => ref.read(_searchProvider.notifier).state = v); },
            )),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: Badge(isLabelVisible: tierFilter.isNotEmpty,
                child: Icon(Icons.filter_list_rounded, color: tierFilter.isNotEmpty ? cs.primary : null)),
              onSelected: (v) => ref.read(_tierFilterProvider.notifier).state = v,
              itemBuilder: (_) => [
                const PopupMenuItem(value: '', child: Text('All Tiers')),
                ..._tiers.map((t) => PopupMenuItem(value: t, child: Row(children: [
                  Icon(_tierIcon(t), size: 16, color: _tierColor(t)), const SizedBox(width: 8),
                  Text(t[0].toUpperCase() + t.substring(1))]))),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1),
        // List
        Expanded(child: data.when(
          loading: () => const LoadingShimmer(),
          error: (e, _) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_customersProvider)),
          data: (items) {
            if (items.isEmpty) return const EmptyState(icon: Icons.people_outline_rounded, title: 'No customers');
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_customersProvider),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: items.length,
                itemBuilder: (_, i) => _CustomerCard(customer: items[i], ref: ref)
                  .animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: (30 * i).clamp(0, 300))).slideY(begin: 0.05, end: 0),
              ),
            );
          },
        )),
      ]),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer, required this.ref});
  final dynamic customer;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = customer['name'] ?? 'Unknown';
    final tier = customer['loyalty_tier'] ?? 'bronze';
    final tc = _tierColor(tier);
    final active = customer['is_active'] != false;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(context, customer, ref),
        onLongPress: () => _showActions(context, customer, ref),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(radius: 22, backgroundColor: tc.withValues(alpha: 0.12),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(fontWeight: FontWeight.w800, color: tc, fontSize: 16))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (!active) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: const Text('INACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey)),
                ),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                if ((customer['phone'] ?? '').toString().isNotEmpty) ...[
                  Icon(Icons.phone_rounded, size: 12, color: cs.onSurfaceVariant), const SizedBox(width: 3),
                  Text(customer['phone'], style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 12),
                ],
                if ((customer['email'] ?? '').toString().isNotEmpty) ...[
                  Icon(Icons.email_rounded, size: 12, color: cs.onSurfaceVariant), const SizedBox(width: 3),
                  Expanded(child: Text(customer['email'], style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(_tierIcon(tier), size: 14, color: tc),
                const SizedBox(width: 4),
                Text(tier[0].toUpperCase() + tier.substring(1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tc)),
                const SizedBox(width: 12),
                Text('${customer['loyalty_points'] ?? 0} pts', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('KSH ${_fmtMoney(customer['total_purchases'])}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }
}

void _showDetail(BuildContext context, dynamic c, WidgetRef ref) {
  final cs = Theme.of(context).colorScheme;
  final tier = c['loyalty_tier'] ?? 'bronze';
  final tc = _tierColor(tier);
  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.65, maxChildSize: 0.9, minChildSize: 0.3,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: ListView(controller: scrollCtrl, padding: EdgeInsets.zero, children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [tc.withValues(alpha: 0.12), tc.withValues(alpha: 0.02)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              CircleAvatar(radius: 30, backgroundColor: tc.withValues(alpha: 0.12),
                child: Icon(_tierIcon(tier), size: 28, color: tc)),
              const SizedBox(height: 12),
              Text(c['name'] ?? 'Customer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cs.onSurface)),
              const SizedBox(height: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: tc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('${tier[0].toUpperCase()}${tier.substring(1)} • ${c['loyalty_points'] ?? 0} pts',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tc))),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((c['phone'] ?? '').toString().isNotEmpty) _InfoTile(icon: Icons.phone_rounded, label: 'Phone', value: c['phone']),
            if ((c['email'] ?? '').toString().isNotEmpty) _InfoTile(icon: Icons.email_rounded, label: 'Email', value: c['email']),
            if ((c['address'] ?? '').toString().isNotEmpty) _InfoTile(icon: Icons.location_on_rounded, label: 'Address', value: c['address']),
            _InfoTile(icon: Icons.shopping_bag_rounded, label: 'Total Purchases', value: 'KSH ${_fmtMoney(c['total_purchases'])}'),
            _InfoTile(icon: Icons.receipt_rounded, label: 'Visit Count', value: '${c['visit_count'] ?? 0}'),
            if ((c['notes'] ?? '').toString().isNotEmpty) _InfoTile(icon: Icons.note_rounded, label: 'Notes', value: c['notes']),
          ])),
        ]),
      ),
    ),
  );
}

void _showActions(BuildContext context, dynamic c, WidgetRef ref) {
  showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
      ListTile(leading: const Icon(Icons.visibility_rounded, color: Color(0xFF3B82F6)), title: const Text('View'),
        onTap: () { Navigator.pop(ctx); _showDetail(context, c, ref); }),
      ListTile(leading: const Icon(Icons.edit_rounded, color: Color(0xFFF59E0B)), title: const Text('Edit'),
        onTap: () { Navigator.pop(ctx); _showForm(context, ref, customer: c); }),
      ListTile(leading: const Icon(Icons.delete_rounded, color: Colors.red), title: const Text('Delete', style: TextStyle(color: Colors.red)),
        onTap: () async {
          Navigator.pop(ctx);
          final ok = await _confirm(context, 'Delete Customer?', 'This cannot be undone.');
          if (!ok || !context.mounted) return;
          try {
            await ref.read(dioProvider).delete('/pos/customers/${c['id']}/');
            ref.invalidate(_customersProvider);
            if (context.mounted) _snack(context, 'Customer deleted', Colors.grey);
          } catch (_) { if (context.mounted) _snack(context, 'Failed', Colors.red); }
        }),
    ]),
  )));
}

void _showForm(BuildContext context, WidgetRef ref, {dynamic customer}) {
  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _CustomerFormSheet(ref: ref, customer: customer));
}

class _CustomerFormSheet extends StatefulWidget {
  const _CustomerFormSheet({required this.ref, this.customer});
  final WidgetRef ref; final dynamic customer;
  @override State<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends State<_CustomerFormSheet> {
  late final TextEditingController _nameCtrl, _phoneCtrl, _emailCtrl, _addressCtrl, _notesCtrl;
  bool _isActive = true, _saving = false;
  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameCtrl = TextEditingController(text: c?['name'] ?? '');
    _phoneCtrl = TextEditingController(text: c?['phone'] ?? '');
    _emailCtrl = TextEditingController(text: c?['email'] ?? '');
    _addressCtrl = TextEditingController(text: c?['address'] ?? '');
    _notesCtrl = TextEditingController(text: c?['notes'] ?? '');
    _isActive = c?['is_active'] ?? true;
  }

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose(); _addressCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _isEdit ? const Color(0xFFF59E0B) : const Color(0xFF6366F1);
    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: Column(children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.person_rounded, color: accent, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Text(_isEdit ? 'Edit Customer' : 'New Customer', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 16), const Divider(height: 1),
          ])),
          Expanded(child: ListView(controller: scrollCtrl, padding: const EdgeInsets.all(20), children: [
            _field('Name *', _nameCtrl, hint: 'Full name'),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _field('Phone *', _phoneCtrl, keyboard: TextInputType.phone)),
              const SizedBox(width: 12),
              Expanded(child: _field('Email', _emailCtrl, keyboard: TextInputType.emailAddress)),
            ]),
            const SizedBox(height: 16),
            _field('Address', _addressCtrl, maxLines: 2),
            const SizedBox(height: 16),
            _field('Notes', _notesCtrl, maxLines: 2),
            const SizedBox(height: 16),
            SwitchListTile(title: const Text('Active', style: TextStyle(fontWeight: FontWeight.w600)),
              value: _isActive, onChanged: (v) => setState(() => _isActive = v), contentPadding: EdgeInsets.zero),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
              label: Text(_saving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create Customer')),
              style: FilledButton.styleFrom(backgroundColor: accent, padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
            const SizedBox(height: 20),
          ])),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint, int maxLines = 1, TextInputType? keyboard}) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
      const SizedBox(height: 6),
      TextField(controller: ctrl, maxLines: maxLines, keyboardType: keyboard,
        decoration: InputDecoration(hintText: hint, isDense: true, filled: true,
          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
        style: const TextStyle(fontSize: 14)),
    ]);
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) { _snack(context, 'Name is required', Colors.orange); return; }
    if (_phoneCtrl.text.trim().isEmpty) { _snack(context, 'Phone is required', Colors.orange); return; }
    setState(() => _saving = true);
    try {
      final dio = widget.ref.read(dioProvider);
      final body = {'name': _nameCtrl.text.trim(), 'phone': _phoneCtrl.text.trim(), 'email': _emailCtrl.text,
        'address': _addressCtrl.text, 'notes': _notesCtrl.text, 'is_active': _isActive};
      _isEdit ? await dio.patch('/pos/customers/${widget.customer['id']}/', data: body)
              : await dio.post('/pos/customers/', data: body);
      widget.ref.invalidate(_customersProvider);
      if (mounted) { Navigator.pop(context); _snack(context, _isEdit ? 'Updated' : 'Created', const Color(0xFF10B981)); }
    } on DioException catch (e) { if (mounted) _snackErr(context, e); }
    finally { if (mounted) setState(() => _saving = false); }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════
class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});
  final IconData icon; final String label; final String value;
  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: cs.primary)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))])),
    ]));
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.items});
  final List<_Kpi> items;
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: items.map((k) => Expanded(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3), padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(color: k.color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: k.color.withValues(alpha: 0.2))),
      child: Column(children: [
        Text(k.value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: k.color),
          maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(k.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: k.color.withValues(alpha: 0.8)),
          textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ))).toList()),
  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
}

class _Kpi { const _Kpi(this.label, this.value, this.color); final String label; final String value; final Color color; }

Future<bool> _confirm(BuildContext context, String title, String content) async =>
  await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text(title), content: Text(content), actions: [
    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm'))])) ?? false;

void _snack(BuildContext context, String msg, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, backgroundColor: color));
}
void _snackErr(BuildContext context, DioException e) {
  final d = e.response?.data; String msg = 'Request failed';
  if (d is Map) { msg = d.entries.map((e) => '${e.key}: ${e.value is List ? (e.value as List).join(', ') : e.value}').join('\n'); }
  else if (d is String && d.isNotEmpty) { msg = d; }
  _snack(context, msg, Colors.red);
}
