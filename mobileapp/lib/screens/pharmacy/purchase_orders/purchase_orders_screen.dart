import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

double _dbl(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
final _fmt = NumberFormat.compactCurrency(symbol: 'KSH ', decimalDigits: 0);

final _posProvider = FutureProvider.autoDispose<List>((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/purchase-orders/orders/', queryParameters: {'page_size': 500, 'ordering': '-order_date'});
  return (res.data['results'] as List?) ?? [];
});

class PurchaseOrdersScreen extends ConsumerStatefulWidget {
  const PurchaseOrdersScreen({super.key});
  @override
  ConsumerState<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends ConsumerState<PurchaseOrdersScreen> {
  String _search = '';
  String _statusFilter = 'all';
  final _searchCtrl = TextEditingController();

  static const _statuses = ['all', 'draft', 'sent', 'received', 'partial', 'returned', 'cancelled'];
  static const _statusLabels = <String, String>{
    'all': 'All', 'draft': 'Draft', 'sent': 'Sent', 'received': 'Received',
    'partial': 'Partial', 'returned': 'Returned', 'cancelled': 'Cancelled',
  };
  static const _statusColors = <String, Color>{
    'draft': Color(0xFF64748B), 'sent': Color(0xFF3B82F6), 'received': Color(0xFF22C55E),
    'partial': Color(0xFFF59E0B), 'returned': Color(0xFF8B5CF6), 'cancelled': Color(0xFFEF4444),
  };

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final posAsync = ref.watch(_posProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: () => ref.invalidate(_posProvider)),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, size: 22),
              style: IconButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary),
              onPressed: () async {
                await context.push('/purchase-orders/new');
                ref.invalidate(_posProvider);
              },
            ),
          ),
        ],
      ),
      body: posAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorRetry(message: 'Failed to load purchase orders', onRetry: () => ref.invalidate(_posProvider)),
        data: (orders) {
          final filtered = orders.where((po) {
            if (_search.isNotEmpty) {
              final q = _search.toLowerCase();
              final poNum = (po['po_number'] ?? '').toString().toLowerCase();
              final supplier = (po['supplier_name'] ?? '').toString().toLowerCase();
              if (!poNum.contains(q) && !supplier.contains(q)) return false;
            }
            if (_statusFilter != 'all' && po['status'] != _statusFilter) return false;
            return true;
          }).toList();

          // Stats
          final totalSpend = orders.fold<double>(0, (s, po) => s + _dbl(po['total_cost']));
          final openCount = orders.where((po) => ['draft', 'sent', 'partial'].contains(po['status'])).length;
          final receivedCount = orders.where((po) => po['status'] == 'received').length;

          return Column(children: [
            // ── Stat Cards ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(
                height: 72,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  _StatPill(Icons.account_balance_wallet_rounded, _fmt.format(totalSpend), 'Spend', const Color(0xFF3B82F6), cs),
                  _StatPill(Icons.shopping_cart_rounded, '${orders.length}', 'Total', cs.primary, cs),
                  _StatPill(Icons.schedule_rounded, '$openCount', 'Open', const Color(0xFFF59E0B), cs),
                  _StatPill(Icons.check_circle_rounded, '$receivedCount', 'Received', const Color(0xFF22C55E), cs),
                ]),
              ),
            ),

            // ── Search ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: TextField(
                controller: _searchCtrl, onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search PO #, supplier...', hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _search.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); }) : null,
                  isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),

            // ── Status Filters ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(
                height: 32,
                child: ListView(scrollDirection: Axis.horizontal, children: _statuses.map((s) {
                  final count = s == 'all' ? orders.length : orders.where((po) => po['status'] == s).length;
                  return _FilterChip(label: '${_statusLabels[s]} ($count)', selected: _statusFilter == s, onTap: () => setState(() => _statusFilter = s), color: _statusColors[s]);
                }).toList()),
              ),
            ),

            // ── List ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('${filtered.length} orders', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(icon: Icons.shopping_cart_outlined, title: 'No purchase orders')
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(_posProvider),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _POCard(po: filtered[i], cs: cs, onAction: (action) => _handleAction(action, filtered[i])),
                      ),
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Future<void> _handleAction(String action, Map po) async {
    final id = po['id'];
    switch (action) {
      case 'view':
        await context.push('/purchase-orders/$id');
        ref.invalidate(_posProvider);
        break;
      case 'edit':
        await context.push('/purchase-orders/$id/edit');
        ref.invalidate(_posProvider);
        break;
      case 'receive':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Mark as Received'),
            content: Text('Mark ${po['po_number']} as received? This will update stock quantities.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Receive')),
            ],
          ),
        );
        if (confirm != true) return;
        try {
          await ref.read(dioProvider).patch('/purchase-orders/orders/$id/', data: {'status': 'received'});
          ref.invalidate(_posProvider);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${po['po_number']} marked received & stock updated')));
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
        }
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Purchase Order'),
            content: Text('Delete ${po['po_number']}? This cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
            ],
          ),
        );
        if (confirm != true) return;
        try {
          await ref.read(dioProvider).delete('/purchase-orders/orders/$id/');
          ref.invalidate(_posProvider);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase order deleted')));
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
        }
        break;
    }
  }
}

// ══════════════════════════════════════════
// PO Card
// ══════════════════════════════════════════
class _POCard extends StatelessWidget {
  final Map po;
  final ColorScheme cs;
  final void Function(String action) onAction;
  const _POCard({required this.po, required this.cs, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final status = (po['status'] ?? 'draft').toString();
    final statusColor = _PurchaseOrdersScreenState._statusColors[status] ?? const Color(0xFF64748B);
    final statusLabel = _PurchaseOrdersScreenState._statusLabels[status] ?? status;
    final items = (po['items'] as List?) ?? [];
    final date = DateTime.tryParse((po['order_date'] ?? '').toString());
    final fmtDate = date != null ? DateFormat('MMM d, yyyy').format(date) : '';
    final expectedDate = DateTime.tryParse((po['expected_delivery'] ?? '').toString());
    final fmtExpected = expectedDate != null ? DateFormat('MMM d, yyyy').format(expectedDate) : '';
    final initials = _getInitials(po['supplier_name'] ?? '');

    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.15))),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onAction('view'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header row
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(po['po_number'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.primary)),
                const SizedBox(height: 2),
                Text(fmtDate, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
              ),
            ]),
            const SizedBox(height: 10),

            // Supplier row
            Row(children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: cs.primaryContainer.withValues(alpha: 0.5),
                child: Text(initials, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: cs.primary)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(po['supplier_name'] ?? 'No supplier', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 10),

            // Divider
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
            const SizedBox(height: 10),

            // Footer row
            Row(children: [
              _InfoChip(label: '${items.length} items', icon: Icons.inventory_2_rounded, cs: cs),
              const SizedBox(width: 12),
              if (fmtExpected.isNotEmpty) ...[
                Icon(Icons.calendar_today_rounded, size: 12, color: cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(fmtExpected, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ],
              const Spacer(),
              Text(_fmt.format(_dbl(po['total_cost'])), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: cs.primary)),
            ]),
            const SizedBox(height: 8),

            // Actions
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (status != 'received' && status != 'cancelled')
                _ActionBtn(icon: Icons.check_circle_outline_rounded, color: const Color(0xFF22C55E), tooltip: 'Mark Received', onTap: () => onAction('receive')),
              _ActionBtn(icon: Icons.edit_rounded, color: cs.primary, tooltip: 'Edit', onTap: () => onAction('edit')),
              _ActionBtn(icon: Icons.delete_outline_rounded, color: Colors.red, tooltip: 'Delete', onTap: () => onAction('delete')),
            ]),
          ]),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.03);
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2);
    return parts.map((p) => p[0]).join().toUpperCase();
  }
}

class _InfoChip extends StatelessWidget {
  final String label; final IconData icon; final ColorScheme cs;
  const _InfoChip({required this.label, required this.icon, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: cs.onSurfaceVariant),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon; final Color color; final String tooltip; final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon; final String value; final String label; final Color color; final ColorScheme cs;
  const _StatPill(this.icon, this.value, this.label, this.color, this.cs);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: cs.onSurface)),
          Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        ]),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap; final Color? color;
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? c.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? c.withValues(alpha: 0.4) : cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? c : cs.onSurfaceVariant)),
        ),
      ),
    );
  }
}
