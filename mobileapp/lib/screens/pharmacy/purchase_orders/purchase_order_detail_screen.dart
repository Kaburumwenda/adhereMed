import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';

double _dbl(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
final _fmt = NumberFormat.compactCurrency(symbol: 'KSH ', decimalDigits: 0);

class PurchaseOrderDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const PurchaseOrderDetailScreen({super.key, required this.id});
  @override
  ConsumerState<PurchaseOrderDetailScreen> createState() => _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends ConsumerState<PurchaseOrderDetailScreen> {
  late final _poProvider = FutureProvider.autoDispose<Map>((ref) async {
    final dio = ref.read(dioProvider);
    final res = await dio.get('/purchase-orders/orders/${widget.id}/');
    return res.data as Map;
  });

  static const _statusColors = <String, Color>{
    'draft': Color(0xFF64748B), 'sent': Color(0xFF3B82F6), 'received': Color(0xFF22C55E),
    'partial': Color(0xFFF59E0B), 'returned': Color(0xFF8B5CF6), 'cancelled': Color(0xFFEF4444),
  };
  static const _statusLabels = <String, String>{
    'draft': 'Draft', 'sent': 'Sent', 'received': 'Received',
    'partial': 'Partial', 'returned': 'Returned', 'cancelled': 'Cancelled',
  };

  Future<void> _markReceived() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark as Received'),
        content: const Text('This will update stock quantities and create batches.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Receive')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(dioProvider).patch('/purchase-orders/orders/${widget.id}/', data: {'status': 'received'});
      ref.invalidate(_poProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as received & stock updated')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final poAsync = ref.watch(_poProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Order')),
      body: poAsync.when(
        loading: () => const LoadingShimmer(),
        error: (e, _) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_poProvider)),
        data: (po) {
          final status = (po['status'] ?? 'draft').toString();
          final statusColor = _statusColors[status] ?? const Color(0xFF64748B);
          final statusLabel = _statusLabels[status] ?? status;
          final items = (po['items'] as List?) ?? [];
          final orderDate = DateTime.tryParse((po['order_date'] ?? '').toString());
          final expectedDate = DateTime.tryParse((po['expected_delivery'] ?? '').toString());
          final totalCost = _dbl(po['total_cost']);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Hero Card ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(po['po_number'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor == const Color(0xFF22C55E) ? Colors.white : Colors.white)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.local_shipping_rounded, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(po['supplier_name'] ?? 'No supplier', style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 6),
                  if (orderDate != null) Row(children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white60),
                    const SizedBox(width: 6),
                    Text('Ordered: ${DateFormat('MMM d, yyyy').format(orderDate)}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ]),
                  if (expectedDate != null) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.schedule_rounded, size: 14, color: Colors.white60),
                      const SizedBox(width: 6),
                      Text('Expected: ${DateFormat('MMM d, yyyy').format(expectedDate)}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ]),
                  ],
                  const SizedBox(height: 16),
                  Text(_fmt.format(totalCost), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                  Text('Total Cost', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
                ]),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04),
              const SizedBox(height: 16),

              // ── Action Buttons ──
              if (status != 'received' && status != 'cancelled' && status != 'returned')
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    width: double.infinity, height: 44,
                    child: FilledButton.icon(
                      onPressed: _markReceived,
                      icon: const Icon(Icons.check_circle_rounded, size: 20),
                      label: const Text('Mark as Received'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
                    ),
                  ),
                ),

              // ── Items ──
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.inventory_2_rounded, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      const Text('Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(6)),
                        child: Text('${items.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.primary)),
                      ),
                    ]),
                    const SizedBox(height: 12),

                    if (items.isEmpty)
                      Center(child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text('No items', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ))
                    else
                      ...items.asMap().entries.map((entry) {
                        final i = entry.key;
                        final it = entry.value;
                        final qty = it['qty'] ?? 0;
                        final unitCost = _dbl(it['unit_cost']);
                        final lineTotal = _dbl(it['total'] ?? (qty * unitCost));
                        final synced = it['_synced'] == true;
                        final expiryStr = it['expiry_date'] ?? '';
                        final expiry = DateTime.tryParse(expiryStr.toString());

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(
                                width: 22, height: 22,
                                decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                child: Center(child: Text('${i + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cs.primary))),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(it['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              if (synced) Icon(Icons.sync_rounded, size: 14, color: cs.primary),
                            ]),
                            const SizedBox(height: 8),
                            Wrap(spacing: 6, runSpacing: 4, children: [
                              _DetailChip('Qty: $qty', cs.primary, cs),
                              _DetailChip('Cost: ${_fmt.format(unitCost)}', const Color(0xFF3B82F6), cs),
                              _DetailChip('Sell: ${_fmt.format(_dbl(it['unit_selling_price']))}', const Color(0xFF22C55E), cs),
                              if (it['batch_number'] != null && it['batch_number'].toString().isNotEmpty)
                                _DetailChip('Batch: ${it['batch_number']}', const Color(0xFF64748B), cs),
                              if (expiry != null)
                                _DetailChip('Exp: ${DateFormat('MMM yyyy').format(expiry)}', const Color(0xFFF59E0B), cs),
                            ]),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(_fmt.format(lineTotal), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.primary)),
                            ),
                          ]),
                        );
                      }),
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              // ── Notes ──
              if ((po['notes'] ?? '').toString().isNotEmpty)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.notes_rounded, size: 18, color: cs.primary),
                        const SizedBox(width: 8),
                        const Text('Notes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 8),
                      Text(po['notes'].toString(), style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                    ]),
                  ),
                ),

              // ── Details ──
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2))),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      const Text('Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 12),
                    _DetailRow('Status', statusLabel, statusColor),
                    _DetailRow('Supplier', po['supplier_name'] ?? '—', cs.onSurface),
                    if (orderDate != null) _DetailRow('Order Date', DateFormat('MMM d, yyyy').format(orderDate), cs.onSurface),
                    if (expectedDate != null) _DetailRow('Expected Delivery', DateFormat('MMM d, yyyy').format(expectedDate), cs.onSurface),
                    _DetailRow('Items', '${items.length}', cs.onSurface),
                    _DetailRow('Total Cost', _fmt.format(totalCost), cs.primary),
                    if (po['ordered_by_name'] != null) _DetailRow('Ordered By', po['ordered_by_name'].toString(), cs.onSurface),
                  ]),
                ),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String text; final Color color; final ColorScheme cs;
  const _DetailChip(this.text, this.color, this.cs);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(5)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label; final String value; final Color valueColor;
  const _DetailRow(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: valueColor)),
      ]),
    );
  }
}
