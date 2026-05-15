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
final _activeFilterProvider = StateProvider<String>((ref) => '');

final _suppliersProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final params = <String, dynamic>{'page_size': 300};
  final af = ref.watch(_activeFilterProvider);
  if (af == 'active') params['is_active'] = true;
  if (af == 'inactive') params['is_active'] = false;
  final res = await dio.get('/suppliers/', queryParameters: params);
  final items = (res.data['results'] as List?) ?? (res.data is List ? res.data as List : []);
  final q = ref.watch(_searchProvider).toLowerCase();
  if (q.isEmpty) return items;
  return items.where((s) =>
    '${s['name'] ?? ''}'.toLowerCase().contains(q) ||
    '${s['contact_person'] ?? ''}'.toLowerCase().contains(q) ||
    '${s['phone'] ?? ''}'.toLowerCase().contains(q) ||
    '${s['email'] ?? ''}'.toLowerCase().contains(q)
  ).toList();
});

String _fmtMoney(dynamic v) {
  if (v == null) return '0.00';
  return NumberFormat('#,##0.00').format(double.tryParse(v.toString()) ?? 0);
}

const _paymentTermOptions = ['Cash on delivery', 'Net 7', 'Net 15', 'Net 30', 'Net 45', 'Net 60', 'Prepaid'];

// ═══════════════════════════════════════════════════════════════════════════
//  SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});
  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  Timer? _debounce;
  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = ref.watch(_suppliersProvider);
    final activeFilter = ref.watch(_activeFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Suppliers', style: TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Supplier'),
      ),
      body: Column(children: [
        // KPIs
        data.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            final active = items.where((s) => s['is_active'] != false).length;
            final inactive = items.length - active;
            final withItems = items.where((s) => ((s['items'] as List?)?.isNotEmpty ?? false)).length;
            return _KpiRow(items: [
              _Kpi('Total', '${items.length}', const Color(0xFF6366F1)),
              _Kpi('Active', '$active', const Color(0xFF10B981)),
              _Kpi('Inactive', '$inactive', const Color(0xFF94A3B8)),
              _Kpi('With Items', '$withItems', const Color(0xFF3B82F6)),
            ]);
          },
        ),
        // Search + filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(children: [
            Expanded(child: TextField(
              decoration: InputDecoration(hintText: 'Search suppliers...', prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true, filled: true, fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              style: const TextStyle(fontSize: 14),
              onChanged: (v) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 300), () => ref.read(_searchProvider.notifier).state = v); },
            )),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: Badge(isLabelVisible: activeFilter.isNotEmpty,
                child: Icon(Icons.filter_list_rounded, color: activeFilter.isNotEmpty ? cs.primary : null)),
              onSelected: (v) => ref.read(_activeFilterProvider.notifier).state = v,
              itemBuilder: (_) => const [
                PopupMenuItem(value: '', child: Text('All')),
                PopupMenuItem(value: 'active', child: Text('Active')),
                PopupMenuItem(value: 'inactive', child: Text('Inactive')),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1),
        // List
        Expanded(child: data.when(
          loading: () => const LoadingShimmer(),
          error: (e, _) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_suppliersProvider)),
          data: (items) {
            if (items.isEmpty) return const EmptyState(icon: Icons.local_shipping_rounded, title: 'No suppliers');
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_suppliersProvider),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: items.length,
                itemBuilder: (_, i) => _SupplierCard(supplier: items[i], ref: ref)
                  .animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: (30 * i).clamp(0, 300))).slideY(begin: 0.05, end: 0),
              ),
            );
          },
        )),
      ]),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({required this.supplier, required this.ref});
  final dynamic supplier;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = supplier['name'] ?? 'Unknown';
    final active = supplier['is_active'] != false;
    final sc = active ? const Color(0xFF10B981) : const Color(0xFF94A3B8);
    final itemCount = (supplier['items'] as List?)?.length ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(context, supplier, ref),
        onLongPress: () => _showActions(context, supplier, ref),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(radius: 22, backgroundColor: sc.withValues(alpha: 0.12),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(fontWeight: FontWeight.w800, color: sc, fontSize: 16))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(active ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: sc, letterSpacing: 0.5))),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                if ((supplier['contact_person'] ?? '').toString().isNotEmpty) ...[
                  Icon(Icons.person_rounded, size: 12, color: cs.onSurfaceVariant), const SizedBox(width: 3),
                  Text(supplier['contact_person'], style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(width: 12),
                ],
                if ((supplier['phone'] ?? '').toString().isNotEmpty) ...[
                  Icon(Icons.phone_rounded, size: 12, color: cs.onSurfaceVariant), const SizedBox(width: 3),
                  Text(supplier['phone'], style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ]),
              const SizedBox(height: 6),
              Row(children: [
                if ((supplier['payment_terms'] ?? '').toString().isNotEmpty) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(supplier['payment_terms'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6))),
                ),
                const Spacer(),
                Text('$itemCount items', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }
}

void _showDetail(BuildContext context, dynamic s, WidgetRef ref) {
  final cs = Theme.of(context).colorScheme;
  final active = s['is_active'] != false;
  final sc = active ? const Color(0xFF10B981) : const Color(0xFF94A3B8);
  final items = (s['items'] as List?) ?? [];

  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.7, maxChildSize: 0.95, minChildSize: 0.3,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: ListView(controller: scrollCtrl, padding: EdgeInsets.zero, children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [sc.withValues(alpha: 0.12), sc.withValues(alpha: 0.02)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              CircleAvatar(radius: 30, backgroundColor: sc.withValues(alpha: 0.12),
                child: Icon(Icons.local_shipping_rounded, size: 28, color: sc)),
              const SizedBox(height: 12),
              Text(s['name'] ?? '', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cs.onSurface)),
              const SizedBox(height: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(active ? 'Active' : 'Inactive', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sc))),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((s['contact_person'] ?? '').toString().isNotEmpty) _InfoTile(icon: Icons.person_rounded, label: 'Contact', value: s['contact_person']),
            if ((s['phone'] ?? '').toString().isNotEmpty) _InfoTile(icon: Icons.phone_rounded, label: 'Phone', value: s['phone']),
            if ((s['email'] ?? '').toString().isNotEmpty) _InfoTile(icon: Icons.email_rounded, label: 'Email', value: s['email']),
            if ((s['payment_terms'] ?? '').toString().isNotEmpty) _InfoTile(icon: Icons.schedule_rounded, label: 'Payment Terms', value: s['payment_terms']),
            if ((s['address'] ?? '').toString().isNotEmpty) _InfoTile(icon: Icons.location_on_rounded, label: 'Address', value: s['address']),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Catalog Items (${items.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...items.map((it) => Container(
                margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3))),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it['item_name'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('Cost: KSH ${_fmtMoney(it['unit_cost'])} • Price: KSH ${_fmtMoney(it['unit_price'])}',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ])),
                  Text('Qty: ${it['quantity'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ]),
              )),
            ],
          ])),
        ]),
      ),
    ),
  );
}

void _showActions(BuildContext context, dynamic s, WidgetRef ref) {
  showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
      ListTile(leading: const Icon(Icons.visibility_rounded, color: Color(0xFF3B82F6)), title: const Text('View'),
        onTap: () { Navigator.pop(ctx); _showDetail(context, s, ref); }),
      ListTile(leading: const Icon(Icons.edit_rounded, color: Color(0xFFF59E0B)), title: const Text('Edit'),
        onTap: () { Navigator.pop(ctx); _showForm(context, ref, supplier: s); }),
      ListTile(
        leading: Icon(s['is_active'] == true ? Icons.toggle_off_rounded : Icons.toggle_on_rounded,
          color: s['is_active'] == true ? Colors.grey : const Color(0xFF10B981)),
        title: Text(s['is_active'] == true ? 'Deactivate' : 'Activate'),
        onTap: () async {
          Navigator.pop(ctx);
          try {
            await ref.read(dioProvider).patch('/suppliers/${s['id']}/', data: {'is_active': !(s['is_active'] == true)});
            ref.invalidate(_suppliersProvider);
            if (context.mounted) _snack(context, s['is_active'] == true ? 'Deactivated' : 'Activated', const Color(0xFF10B981));
          } catch (_) { if (context.mounted) _snack(context, 'Failed', Colors.red); }
        }),
      ListTile(leading: const Icon(Icons.delete_rounded, color: Colors.red), title: const Text('Delete', style: TextStyle(color: Colors.red)),
        onTap: () async {
          Navigator.pop(ctx);
          final ok = await _confirm(context, 'Delete Supplier?', 'This cannot be undone.');
          if (!ok || !context.mounted) return;
          try {
            await ref.read(dioProvider).delete('/suppliers/${s['id']}/');
            ref.invalidate(_suppliersProvider);
            if (context.mounted) _snack(context, 'Deleted', Colors.grey);
          } catch (_) { if (context.mounted) _snack(context, 'Failed', Colors.red); }
        }),
    ]),
  )));
}

void _showForm(BuildContext context, WidgetRef ref, {dynamic supplier}) {
  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _SupplierFormSheet(ref: ref, supplier: supplier));
}

class _SupplierFormSheet extends StatefulWidget {
  const _SupplierFormSheet({required this.ref, this.supplier});
  final WidgetRef ref; final dynamic supplier;
  @override State<_SupplierFormSheet> createState() => _SupplierFormSheetState();
}

class _SupplierFormSheetState extends State<_SupplierFormSheet> {
  late final TextEditingController _nameCtrl, _contactCtrl, _phoneCtrl, _emailCtrl, _addressCtrl, _termsCtrl;
  bool _isActive = true, _saving = false;
  bool get _isEdit => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _nameCtrl = TextEditingController(text: s?['name'] ?? '');
    _contactCtrl = TextEditingController(text: s?['contact_person'] ?? '');
    _phoneCtrl = TextEditingController(text: s?['phone'] ?? '');
    _emailCtrl = TextEditingController(text: s?['email'] ?? '');
    _addressCtrl = TextEditingController(text: s?['address'] ?? '');
    _termsCtrl = TextEditingController(text: s?['payment_terms'] ?? '');
    _isActive = s?['is_active'] ?? true;
  }

  @override
  void dispose() { _nameCtrl.dispose(); _contactCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose(); _addressCtrl.dispose(); _termsCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _isEdit ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    return DraggableScrollableSheet(
      initialChildSize: 0.88, maxChildSize: 0.95, minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: Column(children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.local_shipping_rounded, color: accent, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Text(_isEdit ? 'Edit Supplier' : 'New Supplier', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 16), const Divider(height: 1),
          ])),
          Expanded(child: ListView(controller: scrollCtrl, padding: const EdgeInsets.all(20), children: [
            _field('Name *', _nameCtrl, hint: 'Supplier name'),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _field('Contact Person', _contactCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _field('Phone', _phoneCtrl, keyboard: TextInputType.phone)),
            ]),
            const SizedBox(height: 16),
            _field('Email', _emailCtrl, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 16),
            // Payment terms with suggestions
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Payment Terms', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 6),
              Autocomplete<String>(
                initialValue: _termsCtrl.value,
                optionsBuilder: (v) => _paymentTermOptions.where((o) => o.toLowerCase().contains(v.text.toLowerCase())),
                onSelected: (v) => _termsCtrl.text = v,
                fieldViewBuilder: (ctx, ctrl, focus, onSubmit) {
                  _termsCtrl.text = ctrl.text;
                  return TextField(controller: ctrl, focusNode: focus,
                    decoration: InputDecoration(hintText: 'e.g. Net 30', isDense: true, filled: true,
                      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    style: const TextStyle(fontSize: 14));
                },
              ),
            ]),
            const SizedBox(height: 16),
            _field('Address', _addressCtrl, maxLines: 2),
            const SizedBox(height: 16),
            SwitchListTile(title: const Text('Active', style: TextStyle(fontWeight: FontWeight.w600)),
              value: _isActive, onChanged: (v) => setState(() => _isActive = v), contentPadding: EdgeInsets.zero),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
              label: Text(_saving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create Supplier')),
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
    setState(() => _saving = true);
    try {
      final dio = widget.ref.read(dioProvider);
      final body = {'name': _nameCtrl.text.trim(), 'contact_person': _contactCtrl.text, 'phone': _phoneCtrl.text,
        'email': _emailCtrl.text, 'address': _addressCtrl.text, 'payment_terms': _termsCtrl.text, 'is_active': _isActive};
      _isEdit ? await dio.patch('/suppliers/${widget.supplier['id']}/', data: body)
              : await dio.post('/suppliers/', data: body);
      widget.ref.invalidate(_suppliersProvider);
      if (mounted) { Navigator.pop(context); _snack(context, _isEdit ? 'Updated' : 'Created', const Color(0xFF10B981)); }
    } on DioException catch (e) { if (mounted) _snackErr(context, e); }
    finally { if (mounted) setState(() => _saving = false); }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHARED
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
  const _KpiRow({required this.items}); final List<_Kpi> items;
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: items.map((k) => Expanded(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3), padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(color: k.color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: k.color.withValues(alpha: 0.2))),
      child: Column(children: [
        Text(k.value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: k.color), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(k.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: k.color.withValues(alpha: 0.8)),
          textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ))).toList()),
  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
}
class _Kpi { const _Kpi(this.label, this.value, this.color); final String label; final String value; final Color color; }

Future<bool> _confirm(BuildContext ctx, String t, String c) async =>
  await showDialog<bool>(context: ctx, builder: (d) => AlertDialog(title: Text(t), content: Text(c), actions: [
    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
    FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Confirm'))])) ?? false;

void _snack(BuildContext c, String m, Color co) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, backgroundColor: co));
void _snackErr(BuildContext c, DioException e) {
  final d = e.response?.data; String m = 'Request failed';
  if (d is Map) { m = d.entries.map((e) => '${e.key}: ${e.value is List ? (e.value as List).join(', ') : e.value}').join('\n'); }
  else if (d is String && d.isNotEmpty) { m = d; }
  _snack(c, m, Colors.red);
}
