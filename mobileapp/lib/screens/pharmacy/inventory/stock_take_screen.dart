import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  STATUS HELPERS
// ═══════════════════════════════════════════════════════════════════════════
const _statusList = ['draft', 'in_progress', 'completed', 'cancelled'];
Color _statusColor(String s) => switch (s) {
  'draft' => const Color(0xFF94A3B8),
  'in_progress' => const Color(0xFF3B82F6),
  'completed' => const Color(0xFF10B981),
  'cancelled' => Colors.red,
  _ => const Color(0xFF94A3B8),
};
IconData _statusIcon(String s) => switch (s) {
  'draft' => Icons.edit_note_rounded,
  'in_progress' => Icons.pending_rounded,
  'completed' => Icons.done_all_rounded,
  'cancelled' => Icons.cancel_rounded,
  _ => Icons.help_outline_rounded,
};
String _statusLabel(String s) => s.replaceAll('_', ' ').split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

// ═══════════════════════════════════════════════════════════════════════════
//  PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════
final _searchProvider = StateProvider<String>((ref) => '');
final _statusFilterProvider = StateProvider<String>((ref) => '');

final _countsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final params = <String, dynamic>{'page_size': 300};
  final sf = ref.watch(_statusFilterProvider);
  if (sf.isNotEmpty) params['status'] = sf;
  final res = await dio.get('/inventory/counts/', queryParameters: params);
  final items = (res.data['results'] as List?) ?? (res.data is List ? res.data as List : []);
  final q = ref.watch(_searchProvider).toLowerCase();
  if (q.isEmpty) return items;
  return items.where((c) =>
    '${c['reference'] ?? ''}'.toLowerCase().contains(q) ||
    '${c['name'] ?? ''}'.toLowerCase().contains(q)
  ).toList();
});

final _branchesProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final res = await dio.get('/tenants/branches/', queryParameters: {'page_size': 100});
    return (res.data['results'] as List?) ?? (res.data is List ? res.data as List : []);
  } catch (_) { return []; }
});

final _categoriesProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final res = await dio.get('/inventory/categories/', queryParameters: {'page_size': 100});
    return (res.data['results'] as List?) ?? (res.data is List ? res.data as List : []);
  } catch (_) { return []; }
});

// ═══════════════════════════════════════════════════════════════════════════
//  SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class StockTakeScreen extends ConsumerStatefulWidget {
  const StockTakeScreen({super.key});
  @override
  ConsumerState<StockTakeScreen> createState() => _StockTakeScreenState();
}

class _StockTakeScreenState extends ConsumerState<StockTakeScreen> {
  Timer? _debounce;
  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = ref.watch(_countsProvider);
    final statusFilter = ref.watch(_statusFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stock Take', style: TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Count'),
      ),
      body: Column(children: [
        // KPIs
        data.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            final draft = items.where((c) => c['status'] == 'draft').length;
            final inProgress = items.where((c) => c['status'] == 'in_progress').length;
            final completed = items.where((c) => c['status'] == 'completed').length;
            return _KpiRow(items: [
              _Kpi('Total', '${items.length}', const Color(0xFF6366F1)),
              _Kpi('Draft', '$draft', const Color(0xFF94A3B8)),
              _Kpi('In Progress', '$inProgress', const Color(0xFF3B82F6)),
              _Kpi('Completed', '$completed', const Color(0xFF10B981)),
            ]);
          },
        ),
        // Search + filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(children: [
            Expanded(child: TextField(
              decoration: InputDecoration(hintText: 'Search counts...', prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true, filled: true, fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              style: const TextStyle(fontSize: 14),
              onChanged: (v) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 300), () => ref.read(_searchProvider.notifier).state = v); },
            )),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: Badge(isLabelVisible: statusFilter.isNotEmpty,
                child: Icon(Icons.filter_list_rounded, color: statusFilter.isNotEmpty ? cs.primary : null)),
              onSelected: (v) => ref.read(_statusFilterProvider.notifier).state = v,
              itemBuilder: (_) => [
                const PopupMenuItem(value: '', child: Text('All Statuses')),
                ..._statusList.map((s) => PopupMenuItem(value: s, child: Row(children: [
                  Icon(_statusIcon(s), size: 16, color: _statusColor(s)), const SizedBox(width: 8),
                  Text(_statusLabel(s))]))),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1),
        // List
        Expanded(child: data.when(
          loading: () => const LoadingShimmer(),
          error: (e, _) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_countsProvider)),
          data: (items) {
            if (items.isEmpty) return const EmptyState(icon: Icons.fact_check_rounded, title: 'No stock counts');
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_countsProvider),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: items.length,
                itemBuilder: (_, i) => _CountCard(count: items[i], ref: ref)
                  .animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: (30 * i).clamp(0, 300))).slideY(begin: 0.05, end: 0),
              ),
            );
          },
        )),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  COUNT CARD
// ═══════════════════════════════════════════════════════════════════════════
class _CountCard extends StatelessWidget {
  const _CountCard({required this.count, required this.ref});
  final dynamic count;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = (count['status'] ?? 'draft').toString();
    final sc = _statusColor(status);
    final refNo = count['reference'] ?? 'CNT-???';
    final name = count['name'] ?? '';
    final lines = (count['lines'] as List?) ?? [];
    final totalLines = lines.length;
    final countedLines = lines.where((l) => l['counted_quantity'] != null).length;
    final progress = totalLines > 0 ? countedLines / totalLines : 0.0;
    final date = _fmtDate(count['created_at']);

    return Card(
      margin: const EdgeInsets.only(bottom: 10), elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(context, count, ref),
        onLongPress: () => _showActions(context, count, ref),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
          child: Column(children: [
            Container(height: 4, decoration: BoxDecoration(color: sc,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)))),
            Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_statusIcon(status), size: 18, color: sc),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(refNo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  if (name.isNotEmpty) Text(name, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ])),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(_statusLabel(status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sc, letterSpacing: 0.3))),
              ]),
              const SizedBox(height: 10),
              // Progress bar
              if (status == 'in_progress' && totalLines > 0) ...[
                Row(children: [
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: progress, minHeight: 6,
                      backgroundColor: cs.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(progress == 1 ? const Color(0xFF10B981) : const Color(0xFF3B82F6))))),
                  const SizedBox(width: 8),
                  Text('$countedLines/$totalLines', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                ]),
                const SizedBox(height: 8),
              ],
              Row(children: [
                Icon(Icons.calendar_today_rounded, size: 12, color: cs.onSurfaceVariant), const SizedBox(width: 4),
                Text(date, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                const Spacer(),
                if ((count['branch_name'] ?? '').toString().isNotEmpty) ...[
                  Icon(Icons.store_rounded, size: 12, color: cs.onSurfaceVariant), const SizedBox(width: 4),
                  Text(count['branch_name'], style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ],
              ]),
              if (count['total_variance'] != null && count['total_variance'] != 0)
                Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
                  Text('Variance: ', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  Text('${count['total_variance']} units', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: (count['total_variance'] as num) < 0 ? Colors.red : Colors.orange)),
                  if (count['total_variance_value'] != null) ...[
                    const Spacer(),
                    Text('KSH ${_fmtMoney(count['total_variance_value'])}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: (double.tryParse('${count['total_variance_value']}') ?? 0) < 0 ? Colors.red : Colors.orange)),
                  ],
                ])),
            ])),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  DETAIL SHEET
// ═══════════════════════════════════════════════════════════════════════════
void _showDetail(BuildContext context, dynamic c, WidgetRef ref) {
  final cs = Theme.of(context).colorScheme;
  final status = (c['status'] ?? 'draft').toString();
  final sc = _statusColor(status);
  final lines = (c['lines'] as List?) ?? [];

  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.8, maxChildSize: 0.95, minChildSize: 0.3,
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
              Icon(_statusIcon(status), size: 36, color: sc),
              const SizedBox(height: 10),
              Text(c['reference'] ?? '', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface)),
              if ((c['name'] ?? '').toString().isNotEmpty)
                Text(c['name'], style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
              const SizedBox(height: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(_statusLabel(status), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sc))),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if ((c['branch_name'] ?? '').toString().isNotEmpty) _InfoTile(icon: Icons.store_rounded, label: 'Branch', value: c['branch_name']),
            if ((c['category_name'] ?? '').toString().isNotEmpty) _InfoTile(icon: Icons.category_rounded, label: 'Category', value: c['category_name']),
            if (c['created_at'] != null) _InfoTile(icon: Icons.schedule_rounded, label: 'Created', value: _fmtDate(c['created_at'])),
            if (c['completed_at'] != null) _InfoTile(icon: Icons.done_rounded, label: 'Completed', value: _fmtDate(c['completed_at'])),
            if ((c['notes'] ?? '').toString().isNotEmpty) _InfoTile(icon: Icons.note_rounded, label: 'Notes', value: c['notes']),
            if (c['total_variance'] != null)
              _InfoTile(icon: Icons.compare_arrows_rounded, label: 'Total Variance',
                value: '${c['total_variance']} units (KSH ${_fmtMoney(c['total_variance_value'])})'),

            // Lines
            if (lines.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Count Lines (${lines.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...lines.map((ln) {
                final stockName = ln['stock_name'] ?? ln['medication_name'] ?? 'Item #${ln['stock'] ?? ''}';
                final expected = ln['expected_quantity'] ?? 0;
                final counted = ln['counted_quantity'];
                final variance = ln['variance'];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3))),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(stockName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text('Expected: $expected', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        const SizedBox(width: 12),
                        Text('Counted: ${counted ?? '-'}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        if (variance != null) ...[
                          const SizedBox(width: 12),
                          Text('Var: $variance', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: (variance as num) < 0 ? Colors.red : (variance as num) > 0 ? Colors.orange : const Color(0xFF10B981))),
                        ],
                      ]),
                    ])),
                  ]),
                );
              }),
            ],

            // Actions
            const SizedBox(height: 16),
            _CountActionButtons(count: c, ref: ref),
          ])),
        ]),
      ),
    ),
  );
}

class _CountActionButtons extends StatelessWidget {
  const _CountActionButtons({required this.count, required this.ref});
  final dynamic count;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final status = (count['status'] ?? 'draft').toString();
    final actions = <Widget>[];

    if (status == 'draft') {
      actions.addAll([
        _ActionBtn(label: 'Generate Sheet', icon: Icons.list_alt_rounded, color: const Color(0xFF3B82F6),
          onTap: () async {
            try {
              await ref.read(dioProvider).post('/inventory/counts/${count['id']}/generate-sheet/');
              ref.invalidate(_countsProvider);
              if (context.mounted) { Navigator.pop(context); _snack(context, 'Sheet generated', const Color(0xFF10B981)); }
            } on DioException catch (e) { if (context.mounted) _snackErr(context, e); }
          }),
        const SizedBox(width: 8),
        _ActionBtn(label: 'Cancel', icon: Icons.cancel_rounded, color: Colors.red,
          onTap: () async {
            try {
              await ref.read(dioProvider).patch('/inventory/counts/${count['id']}/', data: {'status': 'cancelled'});
              ref.invalidate(_countsProvider);
              if (context.mounted) { Navigator.pop(context); _snack(context, 'Cancelled', Colors.grey); }
            } catch (_) { if (context.mounted) _snack(context, 'Failed', Colors.red); }
          }),
      ]);
    } else if (status == 'in_progress') {
      actions.addAll([
        _ActionBtn(label: 'Enter Counts', icon: Icons.edit_rounded, color: const Color(0xFF3B82F6),
          onTap: () { Navigator.pop(context); _showCountEntry(context, count, ref); }),
        const SizedBox(width: 8),
        _ActionBtn(label: 'Complete', icon: Icons.done_all_rounded, color: const Color(0xFF10B981),
          onTap: () async {
            final ok = await _confirm(context, 'Complete Count?', 'This will create stock adjustments for any variances found.');
            if (!ok) return;
            try {
              final res = await ref.read(dioProvider).post('/inventory/counts/${count['id']}/complete/');
              ref.invalidate(_countsProvider);
              final adj = res.data?['adjustments_created'] ?? 0;
              if (context.mounted) { Navigator.pop(context); _snack(context, 'Completed! $adj adjustments created', const Color(0xFF10B981)); }
            } on DioException catch (e) { if (context.mounted) _snackErr(context, e); }
          }),
      ]);
    }

    if (actions.isEmpty) return const SizedBox.shrink();
    return Row(children: actions.map((a) => a is SizedBox ? a : Expanded(child: a)).toList());
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  LONG PRESS ACTIONS
// ═══════════════════════════════════════════════════════════════════════════
void _showActions(BuildContext context, dynamic c, WidgetRef ref) {
  final status = (c['status'] ?? 'draft').toString();
  showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
      ListTile(leading: const Icon(Icons.visibility_rounded, color: Color(0xFF3B82F6)), title: const Text('View Details'),
        onTap: () { Navigator.pop(ctx); _showDetail(context, c, ref); }),
      if (status == 'draft')
        ListTile(leading: const Icon(Icons.list_alt_rounded, color: Color(0xFF3B82F6)), title: const Text('Generate Sheet'),
          onTap: () async {
            Navigator.pop(ctx);
            try {
              await ref.read(dioProvider).post('/inventory/counts/${c['id']}/generate-sheet/');
              ref.invalidate(_countsProvider);
              if (context.mounted) _snack(context, 'Sheet generated', const Color(0xFF10B981));
            } on DioException catch (e) { if (context.mounted) _snackErr(context, e); }
          }),
      if (status == 'in_progress')
        ListTile(leading: const Icon(Icons.edit_rounded, color: Color(0xFFF59E0B)), title: const Text('Enter Counts'),
          onTap: () { Navigator.pop(ctx); _showCountEntry(context, c, ref); }),
      if (status == 'in_progress')
        ListTile(leading: const Icon(Icons.done_all_rounded, color: Color(0xFF10B981)), title: const Text('Complete'),
          onTap: () async {
            Navigator.pop(ctx);
            final ok = await _confirm(context, 'Complete Count?', 'Creates stock adjustments for variances.');
            if (!ok || !context.mounted) return;
            try {
              final res = await ref.read(dioProvider).post('/inventory/counts/${c['id']}/complete/');
              ref.invalidate(_countsProvider);
              if (context.mounted) _snack(context, 'Completed! ${res.data?['adjustments_created'] ?? 0} adjustments', const Color(0xFF10B981));
            } on DioException catch (e) { if (context.mounted) _snackErr(context, e); }
          }),
      if (status == 'draft')
        ListTile(leading: const Icon(Icons.delete_rounded, color: Colors.red), title: const Text('Delete', style: TextStyle(color: Colors.red)),
          onTap: () async {
            Navigator.pop(ctx);
            final ok = await _confirm(context, 'Delete Count?', 'This cannot be undone.');
            if (!ok || !context.mounted) return;
            try {
              await ref.read(dioProvider).delete('/inventory/counts/${c['id']}/');
              ref.invalidate(_countsProvider);
              if (context.mounted) _snack(context, 'Deleted', Colors.grey);
            } catch (_) { if (context.mounted) _snack(context, 'Failed', Colors.red); }
          }),
    ]),
  )));
}

// ═══════════════════════════════════════════════════════════════════════════
//  COUNT ENTRY (save-counts)
// ═══════════════════════════════════════════════════════════════════════════
void _showCountEntry(BuildContext context, dynamic c, WidgetRef ref) {
  final lines = List<Map<String, dynamic>>.from(
    (c['lines'] as List?)?.map((l) => Map<String, dynamic>.from(l)) ?? []);
  final controllers = lines.map((l) =>
    TextEditingController(text: l['counted_quantity']?.toString() ?? '')).toList();
  final noteControllers = lines.map((l) =>
    TextEditingController(text: l['notes'] ?? '')).toList();

  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.3,
      builder: (ctx, scrollCtrl) {
        final cs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(builder: (ctx, setState) => Container(
          decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: Column(children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.edit_rounded, color: Color(0xFF3B82F6), size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Enter Counts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  Text('${c['reference']} • ${lines.length} items', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ])),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 16), const Divider(height: 1),
            ])),
            Expanded(child: ListView(controller: scrollCtrl, padding: const EdgeInsets.all(20), children: [
              ...List.generate(lines.length, (i) {
                final ln = lines[i];
                final stockName = ln['stock_name'] ?? ln['medication_name'] ?? 'Item #${ln['stock'] ?? ''}';
                final expected = ln['expected_quantity'] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(stockName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text('Expected: $expected', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Row(children: [
                      SizedBox(width: 90, child: TextField(
                        controller: controllers[i], textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(isDense: true, filled: true, label: const Text('Count', style: TextStyle(fontSize: 10)),
                          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(
                        controller: noteControllers[i],
                        decoration: InputDecoration(isDense: true, filled: true, hintText: 'Notes (optional)',
                          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                        style: const TextStyle(fontSize: 12),
                      )),
                    ]),
                  ]),
                );
              }),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  final payload = List.generate(lines.length, (i) {
                    final countedText = controllers[i].text.trim();
                    return {
                      'id': lines[i]['id'],
                      if (countedText.isNotEmpty) 'counted_quantity': int.tryParse(countedText) ?? 0,
                      'notes': noteControllers[i].text,
                    };
                  });
                  try {
                    await ref.read(dioProvider).post('/inventory/counts/${c['id']}/save-counts/', data: {'lines': payload});
                    ref.invalidate(_countsProvider);
                    if (ctx.mounted) { Navigator.pop(ctx); _snack(context, 'Counts saved', const Color(0xFF10B981)); }
                  } on DioException catch (e) { if (ctx.mounted) _snackErr(ctx, e); }
                },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save Counts'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
            ])),
          ]),
        ));
      },
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  CREATE FORM
// ═══════════════════════════════════════════════════════════════════════════
void _showCreateForm(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => const _CreateCountSheet());
}

class _CreateCountSheet extends ConsumerStatefulWidget {
  const _CreateCountSheet();
  @override ConsumerState<_CreateCountSheet> createState() => _CreateCountSheetState();
}

class _CreateCountSheetState extends ConsumerState<_CreateCountSheet> {
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  int? _branch, _category;
  bool _saving = false;

  @override
  void dispose() { _nameCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final branches = ref.watch(_branchesProvider);
    final categories = ref.watch(_categoriesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7, maxChildSize: 0.9, minChildSize: 0.4,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: Column(children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.fact_check_rounded, color: Color(0xFF6366F1), size: 22)),
              const SizedBox(width: 12),
              const Expanded(child: Text('New Stock Count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 16), const Divider(height: 1),
          ])),
          Expanded(child: ListView(controller: scrollCtrl, padding: const EdgeInsets.all(20), children: [
            _field('Name *', _nameCtrl, hint: 'e.g. Monthly Count - May'),
            const SizedBox(height: 16),
            Text('Branch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
            const SizedBox(height: 6),
            branches.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Failed to load'),
              data: (list) => DropdownButtonFormField<int>(
                value: _branch, isExpanded: true,
                decoration: InputDecoration(isDense: true, filled: true, fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                items: [
                  const DropdownMenuItem<int>(value: null, child: Text('All branches')),
                  ...list.map<DropdownMenuItem<int>>((b) => DropdownMenuItem(value: b['id'] as int, child: Text(b['name'] ?? ''))),
                ],
                onChanged: (v) => setState(() => _branch = v),
              ),
            ),
            const SizedBox(height: 16),
            Text('Category (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
            const SizedBox(height: 6),
            categories.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Failed to load'),
              data: (list) => DropdownButtonFormField<int>(
                value: _category, isExpanded: true,
                decoration: InputDecoration(isDense: true, filled: true, fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                items: [
                  const DropdownMenuItem<int>(value: null, child: Text('All categories')),
                  ...list.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(value: c['id'] as int, child: Text(c['name'] ?? ''))),
                ],
                onChanged: (v) => setState(() => _category = v),
              ),
            ),
            const SizedBox(height: 16),
            _field('Notes', _notesCtrl, maxLines: 2),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add_rounded, size: 18),
              label: Text(_saving ? 'Creating...' : 'Create Count'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6366F1), padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
            const SizedBox(height: 20),
          ])),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint, int maxLines = 1}) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
      const SizedBox(height: 6),
      TextField(controller: ctrl, maxLines: maxLines,
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
      final body = <String, dynamic>{'name': _nameCtrl.text.trim(), 'notes': _notesCtrl.text};
      if (_branch != null) body['branch'] = _branch;
      if (_category != null) body['category'] = _category;
      await ref.read(dioProvider).post('/inventory/counts/', data: body);
      ref.invalidate(_countsProvider);
      if (mounted) { Navigator.pop(context); _snack(context, 'Count created', const Color(0xFF10B981)); }
    } on DioException catch (e) { if (mounted) _snackErr(context, e); }
    finally { if (mounted) setState(() => _saving = false); }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHARED
// ═══════════════════════════════════════════════════════════════════════════
String _fmtDate(dynamic d) {
  if (d == null) return '-';
  try { return DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(d.toString())); }
  catch (_) { return d.toString(); }
}

String _fmtMoney(dynamic v) {
  if (v == null) return '0.00';
  return NumberFormat('#,##0.00').format(double.tryParse(v.toString()) ?? 0);
}

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

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap});
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  @override Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap, icon: Icon(icon, size: 16, color: color),
    label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    style: OutlinedButton.styleFrom(side: BorderSide(color: color.withValues(alpha: 0.4)),
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );
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
