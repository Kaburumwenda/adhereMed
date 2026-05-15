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
const _statusList = ['draft', 'requested', 'approved', 'in_transit', 'completed', 'cancelled'];
Color _statusColor(String s) => switch (s) {
  'draft' => const Color(0xFF94A3B8),
  'requested' => const Color(0xFFF59E0B),
  'approved' => const Color(0xFF3B82F6),
  'in_transit' => const Color(0xFF06B6D4),
  'completed' => const Color(0xFF10B981),
  'cancelled' => Colors.red,
  _ => const Color(0xFF94A3B8),
};
IconData _statusIcon(String s) => switch (s) {
  'draft' => Icons.edit_note_rounded,
  'requested' => Icons.send_rounded,
  'approved' => Icons.check_circle_outline_rounded,
  'in_transit' => Icons.local_shipping_rounded,
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

final _transfersProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final params = <String, dynamic>{'page_size': 300};
  final sf = ref.watch(_statusFilterProvider);
  if (sf.isNotEmpty) params['status'] = sf;
  final res = await dio.get('/inventory/transfers/', queryParameters: params);
  final items = (res.data['results'] as List?) ?? (res.data is List ? res.data as List : []);
  final q = ref.watch(_searchProvider).toLowerCase();
  if (q.isEmpty) return items;
  return items.where((t) =>
    '${t['reference'] ?? ''}'.toLowerCase().contains(q) ||
    '${t['source_branch_name'] ?? t['source_branch'] ?? ''}'.toString().toLowerCase().contains(q) ||
    '${t['destination_branch_name'] ?? t['dest_branch'] ?? ''}'.toString().toLowerCase().contains(q)
  ).toList();
});

final _branchesProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final res = await dio.get('/tenants/branches/', queryParameters: {'page_size': 100});
    return (res.data['results'] as List?) ?? (res.data is List ? res.data as List : []);
  } catch (_) { return []; }
});

// ═══════════════════════════════════════════════════════════════════════════
//  SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class TransfersScreen extends ConsumerStatefulWidget {
  const TransfersScreen({super.key});
  @override
  ConsumerState<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends ConsumerState<TransfersScreen> {
  Timer? _debounce;
  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = ref.watch(_transfersProvider);
    final statusFilter = ref.watch(_statusFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stock Transfers', style: TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Transfer'),
      ),
      body: Column(children: [
        // KPIs
        data.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            final pending = items.where((t) => t['status'] == 'requested').length;
            final inTransit = items.where((t) => t['status'] == 'in_transit').length;
            final completed = items.where((t) => t['status'] == 'completed').length;
            return _KpiRow(items: [
              _Kpi('Total', '${items.length}', const Color(0xFF6366F1)),
              _Kpi('Pending', '$pending', const Color(0xFFF59E0B)),
              _Kpi('In Transit', '$inTransit', const Color(0xFF06B6D4)),
              _Kpi('Completed', '$completed', const Color(0xFF10B981)),
            ]);
          },
        ),
        // Search + filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(children: [
            Expanded(child: TextField(
              decoration: InputDecoration(hintText: 'Search transfers...', prefixIcon: const Icon(Icons.search_rounded, size: 20),
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
          error: (e, _) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_transfersProvider)),
          data: (items) {
            if (items.isEmpty) return const EmptyState(icon: Icons.swap_horiz_rounded, title: 'No transfers');
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_transfersProvider),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: items.length,
                itemBuilder: (_, i) => _TransferCard(transfer: items[i], ref: ref)
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
//  TRANSFER CARD
// ═══════════════════════════════════════════════════════════════════════════
class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.transfer, required this.ref});
  final dynamic transfer;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = (transfer['status'] ?? 'draft').toString();
    final sc = _statusColor(status);
    final refNo = transfer['reference'] ?? 'TRF-???';
    final srcName = transfer['source_branch_name'] ?? transfer['source_branch']?.toString() ?? '?';
    final dstName = transfer['destination_branch_name'] ?? transfer['dest_branch']?.toString() ?? '?';
    final lines = (transfer['lines'] as List?) ?? [];
    final date = _fmtDate(transfer['requested_at'] ?? transfer['created_at']);

    return Card(
      margin: const EdgeInsets.only(bottom: 10), elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(context, transfer, ref),
        onLongPress: () => _showStatusActions(context, transfer, ref),
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
                Expanded(child: Text(refNo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(_statusLabel(status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sc, letterSpacing: 0.3))),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _BranchChip(name: srcName, color: const Color(0xFFF59E0B)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded, size: 16, color: cs.onSurfaceVariant)),
                _BranchChip(name: dstName, color: const Color(0xFF3B82F6)),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.calendar_today_rounded, size: 12, color: cs.onSurfaceVariant), const SizedBox(width: 4),
                Text(date, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                const Spacer(),
                Icon(Icons.inventory_2_rounded, size: 12, color: cs.onSurfaceVariant), const SizedBox(width: 4),
                Text('${transfer['total_items'] ?? lines.length} items • ${transfer['total_quantity'] ?? ''} units',
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }
}

class _BranchChip extends StatelessWidget {
  const _BranchChip({required this.name, required this.color});
  final String name; final Color color;
  @override Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  DETAIL SHEET
// ═══════════════════════════════════════════════════════════════════════════
void _showDetail(BuildContext context, dynamic t, WidgetRef ref) {
  final cs = Theme.of(context).colorScheme;
  final status = (t['status'] ?? 'draft').toString();
  final sc = _statusColor(status);
  final lines = (t['lines'] as List?) ?? [];

  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.3,
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
              Text(t['reference'] ?? '', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface)),
              const SizedBox(height: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(_statusLabel(status), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sc))),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _InfoTile(icon: Icons.store_rounded, label: 'From',
                value: '${t['source_branch_name'] ?? t['source_branch'] ?? '-'}')),
              const SizedBox(width: 12),
              Expanded(child: _InfoTile(icon: Icons.store_rounded, label: 'To',
                value: '${t['destination_branch_name'] ?? t['dest_branch'] ?? '-'}')),
            ]),
            if (t['requested_at'] != null) _InfoTile(icon: Icons.schedule_rounded, label: 'Requested', value: _fmtDate(t['requested_at'])),
            if (t['shipped_at'] != null) _InfoTile(icon: Icons.local_shipping_rounded, label: 'Shipped', value: _fmtDate(t['shipped_at'])),
            if (t['received_at'] != null) _InfoTile(icon: Icons.done_rounded, label: 'Received', value: _fmtDate(t['received_at'])),
            if ((t['notes'] ?? '').toString().isNotEmpty) _InfoTile(icon: Icons.note_rounded, label: 'Notes', value: t['notes']),
            if (lines.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Transfer Lines (${lines.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...lines.map((ln) {
                final stockName = ln['stock_name'] ?? ln['medication_name'] ?? 'Item #${ln['stock'] ?? ''}';
                final qty = ln['quantity'] ?? 0;
                final received = ln['quantity_received'] ?? 0;
                final variance = (received is num && qty is num) ? received - qty : 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3))),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(stockName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text('Sent: $qty', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        if (status == 'completed') ...[
                          const SizedBox(width: 12),
                          Text('Received: $received', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                          const SizedBox(width: 12),
                          Text('Var: $variance', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: variance < 0 ? Colors.red : variance > 0 ? Colors.orange : const Color(0xFF10B981))),
                        ],
                      ]),
                    ])),
                  ]),
                );
              }),
            ],
            const SizedBox(height: 16),
            _ActionButtons(transfer: t, ref: ref),
          ])),
        ]),
      ),
    ),
  );
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.transfer, required this.ref});
  final dynamic transfer;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final status = (transfer['status'] ?? 'draft').toString();
    final actions = <Widget>[];

    if (status == 'draft') {
      actions.addAll([
        _ActionBtn(label: 'Submit', icon: Icons.send_rounded, color: const Color(0xFFF59E0B),
          onTap: () => _doAction(context, ref, transfer['id'], 'submit', 'Submitted')),
        const SizedBox(width: 8),
        _ActionBtn(label: 'Cancel', icon: Icons.cancel_rounded, color: Colors.red,
          onTap: () => _doAction(context, ref, transfer['id'], 'cancel', 'Cancelled')),
      ]);
    } else if (status == 'requested') {
      actions.addAll([
        _ActionBtn(label: 'Approve', icon: Icons.check_circle_rounded, color: const Color(0xFF3B82F6),
          onTap: () => _doAction(context, ref, transfer['id'], 'approve', 'Approved')),
        const SizedBox(width: 8),
        _ActionBtn(label: 'Cancel', icon: Icons.cancel_rounded, color: Colors.red,
          onTap: () => _doAction(context, ref, transfer['id'], 'cancel', 'Cancelled')),
      ]);
    } else if (status == 'in_transit' || status == 'approved') {
      actions.add(
        _ActionBtn(label: 'Receive', icon: Icons.done_all_rounded, color: const Color(0xFF10B981),
          onTap: () { Navigator.pop(context); _showReceiveDialog(context, transfer, ref); }),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();
    return Row(children: actions.map((a) => a is SizedBox ? a : Expanded(child: a)).toList());
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap});
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  @override Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap, icon: Icon(icon, size: 16, color: color),
    label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    style: OutlinedButton.styleFrom(side: BorderSide(color: color.withValues(alpha: 0.4)),
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );
}

Future<void> _doAction(BuildContext context, WidgetRef ref, dynamic id, String action, String successMsg) async {
  try {
    await ref.read(dioProvider).post('/inventory/transfers/$id/$action/');
    ref.invalidate(_transfersProvider);
    if (context.mounted) { Navigator.pop(context); _snack(context, successMsg, const Color(0xFF10B981)); }
  } on DioException catch (e) { if (context.mounted) _snackErr(context, e); }
}

// ═══════════════════════════════════════════════════════════════════════════
//  STATUS ACTIONS (long press)
// ═══════════════════════════════════════════════════════════════════════════
void _showStatusActions(BuildContext context, dynamic t, WidgetRef ref) {
  final status = (t['status'] ?? 'draft').toString();
  showModalBottomSheet(context: context, builder: (ctx) => SafeArea(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
      ListTile(leading: const Icon(Icons.visibility_rounded, color: Color(0xFF3B82F6)), title: const Text('View Details'),
        onTap: () { Navigator.pop(ctx); _showDetail(context, t, ref); }),
      if (status == 'draft')
        ListTile(leading: const Icon(Icons.send_rounded, color: Color(0xFFF59E0B)), title: const Text('Submit'),
          onTap: () { Navigator.pop(ctx); _doAction(context, ref, t['id'], 'submit', 'Submitted'); }),
      if (status == 'requested')
        ListTile(leading: const Icon(Icons.check_circle_rounded, color: Color(0xFF3B82F6)), title: const Text('Approve'),
          onTap: () { Navigator.pop(ctx); _doAction(context, ref, t['id'], 'approve', 'Approved'); }),
      if (status == 'in_transit' || status == 'approved')
        ListTile(leading: const Icon(Icons.done_all_rounded, color: Color(0xFF10B981)), title: const Text('Receive'),
          onTap: () { Navigator.pop(ctx); _showReceiveDialog(context, t, ref); }),
      if (status == 'draft' || status == 'requested')
        ListTile(leading: const Icon(Icons.cancel_rounded, color: Colors.red), title: const Text('Cancel', style: TextStyle(color: Colors.red)),
          onTap: () async {
            Navigator.pop(ctx);
            final ok = await _confirm(context, 'Cancel Transfer?', 'This action cannot be undone.');
            if (ok && context.mounted) _doAction(context, ref, t['id'], 'cancel', 'Cancelled');
          }),
    ]),
  )));
}

// ═══════════════════════════════════════════════════════════════════════════
//  RECEIVE DIALOG
// ═══════════════════════════════════════════════════════════════════════════
void _showReceiveDialog(BuildContext context, dynamic t, WidgetRef ref) {
  final lines = List<Map<String, dynamic>>.from(
    (t['lines'] as List?)?.map((l) => Map<String, dynamic>.from(l)) ?? []);
  final controllers = lines.map((l) =>
    TextEditingController(text: '${l['quantity'] ?? 0}')).toList();

  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7, maxChildSize: 0.95, minChildSize: 0.3,
      builder: (ctx, scrollCtrl) {
        final cs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(builder: (ctx, setState) => Container(
          decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: Column(children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.done_all_rounded, color: Color(0xFF10B981), size: 22)),
                const SizedBox(width: 12),
                const Expanded(child: Text('Receive Transfer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 16), const Divider(height: 1),
            ])),
            Expanded(child: ListView(controller: scrollCtrl, padding: const EdgeInsets.all(20), children: [
              Text('Enter received quantities for each line:', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              ...List.generate(lines.length, (i) {
                final ln = lines[i];
                final stockName = ln['stock_name'] ?? ln['medication_name'] ?? 'Item #${ln['stock'] ?? ''}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3))),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(stockName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('Sent: ${ln['quantity'] ?? 0}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ])),
                    SizedBox(width: 80, child: TextField(
                      controller: controllers[i], textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(isDense: true, filled: true,
                        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5), label: const Text('Received', style: TextStyle(fontSize: 10)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    )),
                  ]),
                );
              }),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  final payload = List.generate(lines.length, (i) => {
                    'id': lines[i]['id'], 'quantity_received': int.tryParse(controllers[i].text) ?? 0});
                  try {
                    await ref.read(dioProvider).post('/inventory/transfers/${t['id']}/receive/', data: {'lines': payload});
                    ref.invalidate(_transfersProvider);
                    if (ctx.mounted) { Navigator.pop(ctx); _snack(context, 'Transfer received', const Color(0xFF10B981)); }
                  } on DioException catch (e) { if (ctx.mounted) _snackErr(ctx, e); }
                },
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Confirm Receipt'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 16),
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
    builder: (_) => _CreateTransferSheet(ref: ref));
}

class _CreateTransferSheet extends StatefulWidget {
  const _CreateTransferSheet({required this.ref});
  final WidgetRef ref;
  @override State<_CreateTransferSheet> createState() => _CreateTransferSheetState();
}

class _CreateTransferSheetState extends State<_CreateTransferSheet> {
  int? _sourceBranch, _destBranch;
  final _notesCtrl = TextEditingController();
  final _lines = <Map<String, dynamic>>[];
  bool _saving = false;
  Timer? _medDebounce;
  List _medResults = [];
  final _medSearchCtrl = TextEditingController();

  @override
  void dispose() { _notesCtrl.dispose(); _medSearchCtrl.dispose(); _medDebounce?.cancel(); super.dispose(); }

  void _searchMedication(String q) {
    _medDebounce?.cancel();
    _medDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (q.length < 2) { setState(() => _medResults = []); return; }
      try {
        final res = await widget.ref.read(dioProvider).get('/inventory/stock/', queryParameters: {'search': q, 'page_size': 20});
        if (mounted) setState(() => _medResults = (res.data['results'] as List?) ?? []);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final branches = widget.ref.watch(_branchesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.9, maxChildSize: 0.95, minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: Column(children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF6366F1), size: 22)),
              const SizedBox(width: 12),
              const Expanded(child: Text('New Transfer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 16), const Divider(height: 1),
          ])),
          Expanded(child: branches.when(
            loading: () => const LoadingShimmer(),
            error: (_, __) => const Center(child: Text('Failed to load branches')),
            data: (branchList) => ListView(controller: scrollCtrl, padding: const EdgeInsets.all(20), children: [
              Text('From Branch *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: _sourceBranch, isExpanded: true,
                decoration: InputDecoration(isDense: true, filled: true, fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                items: branchList.map<DropdownMenuItem<int>>((b) => DropdownMenuItem(value: b['id'] as int, child: Text(b['name'] ?? 'Branch'))).toList(),
                onChanged: (v) => setState(() => _sourceBranch = v),
              ),
              const SizedBox(height: 16),
              Text('To Branch *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                value: _destBranch, isExpanded: true,
                decoration: InputDecoration(isDense: true, filled: true, fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                items: branchList.map<DropdownMenuItem<int>>((b) => DropdownMenuItem(value: b['id'] as int, child: Text(b['name'] ?? 'Branch'))).toList(),
                onChanged: (v) => setState(() => _destBranch = v),
              ),
              const SizedBox(height: 16),
              Text('Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 6),
              TextField(controller: _notesCtrl, maxLines: 2,
                decoration: InputDecoration(isDense: true, filled: true, fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 20),
              Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
              const SizedBox(height: 8),
              TextField(controller: _medSearchCtrl,
                decoration: InputDecoration(hintText: 'Search medication to add...', prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true, filled: true, fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                style: const TextStyle(fontSize: 14),
                onChanged: _searchMedication),
              if (_medResults.isNotEmpty) Container(
                margin: const EdgeInsets.only(top: 4), constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3))),
                child: ListView(shrinkWrap: true, children: _medResults.map((m) => ListTile(
                  dense: true, title: Text(m['medication_name'] ?? m['name'] ?? '', style: const TextStyle(fontSize: 13)),
                  subtitle: Text('Stock: ${m['quantity'] ?? 0}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  onTap: () => setState(() {
                    _lines.add({'stock': m['id'], 'stock_name': m['medication_name'] ?? m['name'] ?? '', 'quantity': 1, 'available': m['quantity'] ?? 0});
                    _medResults = []; _medSearchCtrl.clear();
                  }),
                )).toList()),
              ),
              const SizedBox(height: 8),
              ..._lines.asMap().entries.map((e) {
                final i = e.key; final ln = e.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3))),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(ln['stock_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('Available: ${ln['available'] ?? '?'}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ])),
                    SizedBox(width: 70, child: TextField(textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(text: '${ln['quantity']}'),
                      onChanged: (v) => ln['quantity'] = int.tryParse(v) ?? 1,
                      decoration: InputDecoration(isDense: true, filled: true,
                        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                    IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                      onPressed: () => setState(() => _lines.removeAt(i))),
                  ]),
                );
              }),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => _save(false),
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Save Draft'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                )),
                const SizedBox(width: 12),
                Expanded(child: FilledButton.icon(
                  onPressed: _saving ? null : () => _save(true),
                  icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 16),
                  label: Text(_saving ? 'Saving...' : 'Submit'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                )),
              ]),
              const SizedBox(height: 20),
            ]),
          )),
        ]),
      ),
    );
  }

  Future<void> _save(bool submit) async {
    if (_sourceBranch == null || _destBranch == null) { _snack(context, 'Select both branches', Colors.orange); return; }
    if (_sourceBranch == _destBranch) { _snack(context, 'Branches must differ', Colors.orange); return; }
    if (_lines.isEmpty) { _snack(context, 'Add at least one item', Colors.orange); return; }
    setState(() => _saving = true);
    try {
      final dio = widget.ref.read(dioProvider);
      final body = {
        'source_branch': _sourceBranch, 'dest_branch': _destBranch, 'notes': _notesCtrl.text,
        'lines': _lines.map((l) => {'stock': l['stock'], 'quantity': l['quantity']}).toList(),
      };
      final res = await dio.post('/inventory/transfers/', data: body);
      if (submit && res.data?['id'] != null) {
        await dio.post('/inventory/transfers/${res.data['id']}/submit/');
      }
      widget.ref.invalidate(_transfersProvider);
      if (mounted) { Navigator.pop(context); _snack(context, submit ? 'Submitted' : 'Saved as draft', const Color(0xFF10B981)); }
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
