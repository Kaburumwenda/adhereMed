import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/api.dart';
import '../../../widgets/common.dart';
import '../branches/map_picker.dart';

// ─── Providers ──────────────────────────────────────
final _searchProvider = StateProvider<String>((ref) => '');
final _statusFilterProvider = StateProvider<String>((ref) => ''); // '', 'pending', etc.

final _deliveriesProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final params = <String, dynamic>{'page_size': 200, 'ordering': '-created_at'};
  final status = ref.watch(_statusFilterProvider);
  if (status.isNotEmpty) params['status'] = status;
  final res = await dio.get('/pharmacy-profile/deliveries/', queryParameters: params);
  final items = (res.data['results'] as List?) ?? (res.data is List ? res.data as List : []);
  final search = ref.watch(_searchProvider).toLowerCase();
  if (search.isEmpty) return items;
  return items.where((d) =>
    '${d['recipient_name'] ?? ''}'.toLowerCase().contains(search) ||
    '${d['recipient_phone'] ?? ''}'.toLowerCase().contains(search) ||
    '${d['delivery_address'] ?? ''}'.toLowerCase().contains(search) ||
    '${d['transaction_number'] ?? ''}'.toLowerCase().contains(search)
  ).toList();
});

final _staffProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/staff/', queryParameters: {'page_size': 500});
  return (res.data['results'] as List?) ?? (res.data is List ? res.data as List : []);
});

// ─── Status helpers ────────────────────────────────
const _statuses = ['pending', 'assigned', 'in_transit', 'delivered', 'failed', 'cancelled'];

const _statusLabels = {
  'pending': 'Pending', 'assigned': 'Assigned', 'in_transit': 'In Transit',
  'delivered': 'Delivered', 'failed': 'Failed', 'cancelled': 'Cancelled',
};

const _transitions = {
  'pending': ['assigned'],
  'assigned': ['in_transit', 'cancelled'],
  'in_transit': ['delivered', 'failed'],
  'delivered': <String>[],
  'failed': ['pending'],
  'cancelled': <String>[],
};

Color _statusColor(String s) => switch (s) {
  'pending' => const Color(0xFFF59E0B),
  'assigned' => const Color(0xFF8B5CF6),
  'in_transit' => const Color(0xFF3B82F6),
  'delivered' => const Color(0xFF22C55E),
  'failed' => const Color(0xFFEF4444),
  'cancelled' => const Color(0xFF6B7280),
  _ => const Color(0xFF6B7280),
};

IconData _statusIcon(String s) => switch (s) {
  'pending' => Icons.schedule_rounded,
  'assigned' => Icons.person_pin_rounded,
  'in_transit' => Icons.local_shipping_rounded,
  'delivered' => Icons.check_circle_rounded,
  'failed' => Icons.error_rounded,
  'cancelled' => Icons.cancel_rounded,
  _ => Icons.help_rounded,
};

String _fmtDate(dynamic d) {
  if (d == null) return '—';
  try {
    final dt = DateTime.parse('$d');
    return DateFormat('MMM d, yyyy • HH:mm').format(dt);
  } catch (_) { return '$d'; }
}

String _fmtCurrency(dynamic v) {
  if (v == null) return 'KSh 0';
  final n = double.tryParse('$v') ?? 0;
  return 'KSh ${NumberFormat('#,##0.00').format(n)}';
}

// ════════════════════════════════════════════════════
// MAIN SCREEN
// ════════════════════════════════════════════════════
class DeliveriesScreen extends ConsumerStatefulWidget {
  const DeliveriesScreen({super.key});
  @override
  ConsumerState<DeliveriesScreen> createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends ConsumerState<DeliveriesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(_deliveriesProvider);
    final cs = Theme.of(context).colorScheme;
    final statusFilter = ref.watch(_statusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deliveries'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => ref.invalidate(_deliveriesProvider)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Delivery'),
      ),
      body: Column(children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search deliveries...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () { _searchCtrl.clear(); ref.read(_searchProvider.notifier).state = ''; })
                  : null,
              isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant)),
            ),
            onChanged: (v) => ref.read(_searchProvider.notifier).state = v,
          ),
        ),

        // Status filter chips
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [
              _FilterChip(label: 'All', selected: statusFilter.isEmpty, color: const Color(0xFF6366F1), onTap: () => ref.read(_statusFilterProvider.notifier).state = ''),
              const SizedBox(width: 6),
              for (final s in _statuses) ...[
                _FilterChip(label: _statusLabels[s]!, selected: statusFilter == s, color: _statusColor(s), onTap: () => ref.read(_statusFilterProvider.notifier).state = s),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),

        // KPI strip
        data.whenOrNull(data: (items) {
          final pending = items.where((d) => d['status'] == 'pending').length;
          final inTransit = items.where((d) => d['status'] == 'in_transit').length;
          final delivered = items.where((d) => d['status'] == 'delivered').length;
          final revenue = items.where((d) => d['status'] == 'delivered').fold<double>(0, (s, d) => s + (double.tryParse('${d['delivery_fee'] ?? 0}') ?? 0));
          return SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              children: [
                _MiniKPI(label: 'Pending', value: '$pending', color: const Color(0xFFF59E0B), icon: Icons.schedule_rounded),
                _MiniKPI(label: 'In Transit', value: '$inTransit', color: const Color(0xFF3B82F6), icon: Icons.local_shipping_rounded),
                _MiniKPI(label: 'Delivered', value: '$delivered', color: const Color(0xFF22C55E), icon: Icons.check_circle_rounded),
                _MiniKPI(label: 'Revenue', value: _fmtCurrency(revenue), color: const Color(0xFF6366F1), icon: Icons.payments_rounded),
              ],
            ),
          );
        }) ?? const SizedBox.shrink(),

        // List
        Expanded(child: data.when(
          loading: () => const LoadingShimmer(),
          error: (e, _) => ErrorRetry(message: 'Failed to load deliveries', onRetry: () => ref.invalidate(_deliveriesProvider)),
          data: (items) {
            if (items.isEmpty) return const EmptyState(icon: Icons.local_shipping_rounded, title: 'No deliveries found', subtitle: 'Create your first delivery');
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_deliveriesProvider),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
                itemCount: items.length,
                itemBuilder: (_, i) => _DeliveryCard(delivery: items[i])
                    .animate().fadeIn(delay: (30 * i).clamp(0, 300).ms, duration: 250.ms),
              ),
            );
          },
        )),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════
// DELIVERY CARD
// ════════════════════════════════════════════════════
class _DeliveryCard extends ConsumerWidget {
  final Map<String, dynamic> delivery;
  const _DeliveryCard({required this.delivery});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final status = '${delivery['status'] ?? 'pending'}';
    final sc = _statusColor(status);
    final name = '${delivery['recipient_name'] ?? ''}'.trim();
    final phone = '${delivery['recipient_phone'] ?? ''}';
    final address = '${delivery['delivery_address'] ?? ''}';
    final txn = '${delivery['transaction_number'] ?? ''}';
    final driver = '${delivery['driver_display'] ?? delivery['assigned_driver_name'] ?? ''}';
    final fee = '${delivery['delivery_fee'] ?? '0'}';
    final created = _fmtDate(delivery['created_at']);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: sc.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetailDialog(context, ref, delivery),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [sc.withValues(alpha: 0.2), sc.withValues(alpha: 0.05)]),
                ),
                child: Icon(_statusIcon(status), size: 20, color: sc),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isNotEmpty ? name : 'Delivery #${delivery['id']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (txn.isNotEmpty)
                  Text('TXN: $txn', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
              ])),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_statusIcon(status), size: 12, color: sc),
                  const SizedBox(width: 3),
                  Text(_statusLabels[status] ?? status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sc)),
                ]),
              ),
              // Menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 20, color: cs.onSurfaceVariant),
                padding: EdgeInsets.zero,
                onSelected: (v) {
                  if (v == 'detail') _showDetailDialog(context, ref, delivery);
                  else if (v == 'assign') _showAssignDialog(context, ref, delivery);
                  else if (v == 'delete') _confirmDelete(context, ref, delivery);
                  else _updateStatus(context, ref, delivery, v);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'detail', child: Row(children: [Icon(Icons.visibility_rounded, size: 18), SizedBox(width: 8), Text('View Details')])),
                  if (status == 'pending')
                    const PopupMenuItem(value: 'assign', child: Row(children: [Icon(Icons.person_add_rounded, size: 18), SizedBox(width: 8), Text('Assign Driver')])),
                  for (final t in (_transitions[status] ?? <String>[]))
                    PopupMenuItem(value: t, child: Row(children: [
                      Icon(_statusIcon(t), size: 18, color: _statusColor(t)),
                      const SizedBox(width: 8),
                      Text('Mark ${_statusLabels[t]}'),
                    ])),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_rounded, size: 18, color: Color(0xFFEF4444)), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Color(0xFFEF4444)))])),
                ],
              ),
            ]),

            const SizedBox(height: 10),
            // Info chips
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (phone.isNotEmpty) _InfoChip(Icons.phone_rounded, phone, const Color(0xFF22C55E)),
              if (address.isNotEmpty) _InfoChip(Icons.location_on_rounded, address, const Color(0xFF6366F1)),
              if (driver.isNotEmpty) _InfoChip(Icons.person_rounded, driver, const Color(0xFF8B5CF6)),
              _InfoChip(Icons.payments_rounded, _fmtCurrency(fee), const Color(0xFF14B8A6)),
            ]),

            // Date
            const SizedBox(height: 8),
            Text(created, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// DETAIL DIALOG
// ════════════════════════════════════════════════════
void _showDetailDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> d) {
  final cs = Theme.of(context).colorScheme;
  final status = '${d['status'] ?? 'pending'}';
  final sc = _statusColor(status);
  final hasGeo = d['latitude'] != null && d['longitude'] != null;

  // Timeline steps for happy path
  const timelineSteps = ['pending', 'assigned', 'in_transit', 'delivered'];
  final stepIndex = timelineSteps.indexOf(status);
  final isFailed = status == 'failed';
  final isCancelled = status == 'cancelled';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(
      expand: false, initialChildSize: 0.7, maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) => ListView(controller: scrollCtrl, padding: const EdgeInsets.all(20), children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),

        // Header
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, color: sc.withValues(alpha: 0.12)),
            child: Icon(_statusIcon(status), size: 24, color: sc),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${d['recipient_name'] ?? 'Delivery #${d['id']}'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(_statusLabels[status] ?? status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sc)),
            ),
          ])),
        ]),
        const SizedBox(height: 20),

        // Status timeline
        if (!isFailed && !isCancelled) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              for (int i = 0; i < timelineSteps.length; i++) ...[
                Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= stepIndex ? _statusColor(timelineSteps[i]).withValues(alpha: 0.15) : cs.outlineVariant.withValues(alpha: 0.1),
                      border: Border.all(color: i <= stepIndex ? _statusColor(timelineSteps[i]) : cs.outlineVariant.withValues(alpha: 0.3), width: 2),
                    ),
                    child: Icon(
                      i <= stepIndex ? Icons.check_rounded : _statusIcon(timelineSteps[i]),
                      size: 14,
                      color: i <= stepIndex ? _statusColor(timelineSteps[i]) : cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_statusLabels[timelineSteps[i]]!, style: TextStyle(fontSize: 8, fontWeight: i <= stepIndex ? FontWeight.w700 : FontWeight.w400, color: i <= stepIndex ? _statusColor(timelineSteps[i]) : cs.onSurfaceVariant.withValues(alpha: 0.5))),
                ])),
                if (i < timelineSteps.length - 1)
                  Expanded(child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    color: i < stepIndex ? _statusColor(timelineSteps[i + 1]).withValues(alpha: 0.4) : cs.outlineVariant.withValues(alpha: 0.2),
                  )),
              ],
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // Failed/cancelled alert
        if (isFailed || isCancelled) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: sc.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sc.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(isFailed ? Icons.error_rounded : Icons.cancel_rounded, size: 20, color: sc),
              const SizedBox(width: 10),
              Expanded(child: Text(
                isFailed ? 'This delivery failed. You can retry by setting it back to Pending.' : 'This delivery was cancelled.',
                style: TextStyle(fontSize: 12, color: sc, fontWeight: FontWeight.w500),
              )),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // Details
        _DetailRow(Icons.person_rounded, 'Recipient', '${d['recipient_name'] ?? '—'}'),
        _DetailRow(Icons.phone_rounded, 'Phone', '${d['recipient_phone'] ?? '—'}'),
        _DetailRow(Icons.location_on_rounded, 'Address', '${d['delivery_address'] ?? '—'}'),
        if (hasGeo) _DetailRow(Icons.my_location_rounded, 'GPS', '${d['latitude']}, ${d['longitude']}'),
        _DetailRow(Icons.receipt_rounded, 'Transaction', '${d['transaction_number'] ?? '—'}'),
        _DetailRow(Icons.person_pin_rounded, 'Driver', '${d['driver_display'] ?? d['assigned_driver_name'] ?? '—'}'),
        _DetailRow(Icons.payments_rounded, 'Fee', _fmtCurrency(d['delivery_fee'])),
        if ('${d['notes'] ?? ''}'.isNotEmpty) _DetailRow(Icons.notes_rounded, 'Notes', '${d['notes']}'),
        _DetailRow(Icons.calendar_today_rounded, 'Created', _fmtDate(d['created_at'])),
        if (d['scheduled_at'] != null) _DetailRow(Icons.event_rounded, 'Scheduled', _fmtDate(d['scheduled_at'])),
        if (d['delivered_at'] != null) _DetailRow(Icons.done_all_rounded, 'Delivered', _fmtDate(d['delivered_at'])),

        // Action buttons
        const SizedBox(height: 16),
        Row(children: [
          if ('${d['recipient_phone'] ?? ''}'.isNotEmpty)
            Expanded(child: OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse('tel:${d['recipient_phone']}')),
              icon: const Icon(Icons.phone_rounded, size: 16),
              label: const Text('Call'),
            )),
          if ('${d['recipient_phone'] ?? ''}'.isNotEmpty && '${d['delivery_address'] ?? ''}'.isNotEmpty) const SizedBox(width: 8),
          if ('${d['delivery_address'] ?? ''}'.isNotEmpty)
            Expanded(child: OutlinedButton.icon(
              onPressed: () {
                final q = hasGeo ? '${d['latitude']},${d['longitude']}' : Uri.encodeComponent('${d['delivery_address']}');
                launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'));
              },
              icon: const Icon(Icons.map_rounded, size: 16),
              label: const Text('Map'),
            )),
        ]),
        if ('${d['delivery_address'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '${d['delivery_address']}'));
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Address copied'), behavior: SnackBarBehavior.floating));
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Address'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
          ),
        ],

        // Status transition buttons
        if ((_transitions[status] ?? []).isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text('Update Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (status == 'pending')
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAssignDialog(context, ref, d);
                },
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Assign Driver'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
              ),
            for (final t in (_transitions[status] ?? <String>[]))
              if (t != 'assigned') // assigned is handled via assign dialog
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _updateStatus(context, ref, d, t);
                  },
                  icon: Icon(_statusIcon(t), size: 16),
                  label: Text(_statusLabels[t]!),
                  style: FilledButton.styleFrom(backgroundColor: _statusColor(t)),
                ),
          ]),
        ],
      ]),
    ),
  );
}

// ════════════════════════════════════════════════════
// CREATE DELIVERY DIALOG
// ════════════════════════════════════════════════════
void _showCreateDialog(BuildContext context, WidgetRef ref) {
  final formKey = GlobalKey<FormState>();
  final recipientCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final feeCtrl = TextEditingController(text: '0');
  final notesCtrl = TextEditingController();
  final txnSearchCtrl = TextEditingController();

  int? selectedTxnId;
  String? selectedTxnLabel;
  bool saving = false;
  bool searchingTxn = false;
  List<Map<String, dynamic>> txnResults = [];
  Timer? debounce;
  String latValue = '';
  String lngValue = '';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => StatefulBuilder(builder: (ctx, setState) {
      final cs = Theme.of(ctx).colorScheme;

      void searchTxn(String q) {
        debounce?.cancel();
        if (q.length < 2) { setState(() { txnResults = []; }); return; }
        debounce = Timer(const Duration(milliseconds: 300), () async {
          setState(() => searchingTxn = true);
          try {
            final dio = ref.read(dioProvider);
            final res = await dio.get('/pos/transactions/', queryParameters: {'search': q, 'page_size': 25, 'ordering': '-created_at'});
            final items = (res.data['results'] as List?) ?? [];
            if (ctx.mounted) setState(() { txnResults = items.cast<Map<String, dynamic>>(); searchingTxn = false; });
          } catch (_) {
            if (ctx.mounted) setState(() => searchingTxn = false);
          }
        });
      }

      return DraggableScrollableSheet(
        expand: false, initialChildSize: 0.88, maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Form(
          key: formKey,
          child: ListView(controller: scrollCtrl, padding: const EdgeInsets.all(20), children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.local_shipping_rounded, size: 22, color: cs.primary),
              const SizedBox(width: 10),
              const Text('New Delivery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 20),

            // Transaction search
            Text('POS Transaction', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: txnSearchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by transaction number or customer...',
                isDense: true,
                prefixIcon: searchingTxn
                    ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                    : const Icon(Icons.receipt_long_rounded, size: 18),
                suffixIcon: selectedTxnId != null
                    ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () {
                        setState(() { selectedTxnId = null; selectedTxnLabel = null; txnSearchCtrl.clear(); txnResults = []; });
                      })
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: searchTxn,
              readOnly: selectedTxnId != null,
            ),

            if (selectedTxnId != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF22C55E)),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Selected: $selectedTxnLabel', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF22C55E)))),
                ]),
              ),
            ],

            // Transaction results
            if (txnResults.isNotEmpty && selectedTxnId == null) ...[
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
                ),
                child: ListView.separated(
                  shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: txnResults.length,
                  separatorBuilder: (_, __) => Divider(height: 1, indent: 44, color: cs.outlineVariant.withValues(alpha: 0.15)),
                  itemBuilder: (_, i) {
                    final t = txnResults[i];
                    final txnNum = '${t['transaction_number'] ?? '#${t['id']}'}';
                    final custName = '${t['customer_name'] ?? t['customer']?['name'] ?? ''}';
                    final custPhone = '${t['customer_phone'] ?? t['customer']?['phone'] ?? ''}';
                    return ListTile(
                      dense: true, visualDensity: VisualDensity.compact,
                      leading: Icon(Icons.receipt_rounded, size: 18, color: cs.primary),
                      title: Text(txnNum, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      subtitle: custName.isNotEmpty ? Text(custName, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)) : null,
                      onTap: () {
                        setState(() {
                          selectedTxnId = t['id'];
                          selectedTxnLabel = txnNum;
                          txnSearchCtrl.text = txnNum;
                          txnResults = [];
                          // Auto-fill from customer
                          if (custName.isNotEmpty && recipientCtrl.text.isEmpty) recipientCtrl.text = custName;
                          if (custPhone.isNotEmpty && phoneCtrl.text.isEmpty) phoneCtrl.text = custPhone;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Recipient
            TextFormField(
              controller: recipientCtrl,
              decoration: const InputDecoration(labelText: 'Recipient Name *', isDense: true, prefixIcon: Icon(Icons.person_rounded, size: 18)),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            // Phone
            TextFormField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Recipient Phone *', isDense: true, prefixIcon: Icon(Icons.phone_rounded, size: 18)),
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            // Address with Places autocomplete + map picker + GPS
            PlacesAutocompleteField(
              controller: addressCtrl,
              onPicked: (loc) {
                setState(() {
                  addressCtrl.text = loc.address;
                  latValue = loc.latitude.toStringAsFixed(6);
                  lngValue = loc.longitude.toStringAsFixed(6);
                });
              },
              onPickOnMap: () async {
                final result = await Navigator.push<PickedLocation>(
                  ctx,
                  MaterialPageRoute(builder: (_) => MapPickerPage(
                    initialLat: latValue.isNotEmpty ? double.tryParse(latValue) : null,
                    initialLng: lngValue.isNotEmpty ? double.tryParse(lngValue) : null,
                  )),
                );
                if (result != null) {
                  setState(() {
                    addressCtrl.text = result.address;
                    latValue = result.latitude.toStringAsFixed(6);
                    lngValue = result.longitude.toStringAsFixed(6);
                  });
                }
              },
              onUseGps: () async {
                try {
                  LocationPermission perm = await Geolocator.checkPermission();
                  if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
                  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Location permission denied'), behavior: SnackBarBehavior.floating));
                    return;
                  }
                  final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
                  setState(() { latValue = pos.latitude.toStringAsFixed(6); lngValue = pos.longitude.toStringAsFixed(6); });
                  // Reverse geocode
                  try {
                    final geocodeDio = Dio();
                    final res = await geocodeDio.get('https://maps.googleapis.com/maps/api/geocode/json',
                      queryParameters: {'latlng': '${pos.latitude},${pos.longitude}', 'key': 'AIzaSyAhiNO62geg58-WaLGeq235Lo8gySLvs_I'});
                    final results = (res.data['results'] as List?) ?? [];
                    if (results.isNotEmpty && ctx.mounted) {
                      setState(() { addressCtrl.text = results[0]['formatted_address'] ?? ''; });
                    }
                    geocodeDio.close();
                  } catch (_) {}
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('GPS error: $e'), behavior: SnackBarBehavior.floating));
                }
              },
            ),
            if (addressCtrl.text.isNotEmpty && latValue.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF22C55E)),
                    const SizedBox(width: 6),
                    Text('Location: $latValue, $lngValue', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF22C55E))),
                  ]),
                ),
              ),
            const SizedBox(height: 14),

            // Fee
            TextFormField(
              controller: feeCtrl,
              decoration: const InputDecoration(labelText: 'Delivery Fee', isDense: true, prefixIcon: Icon(Icons.payments_rounded, size: 18)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 14),

            // Notes
            TextFormField(
              controller: notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes', isDense: true, prefixIcon: Icon(Icons.notes_rounded, size: 18)),
              maxLines: 3, minLines: 1,
            ),
            const SizedBox(height: 24),

            // Submit
            FilledButton.icon(
              onPressed: saving ? null : () async {
                if (!formKey.currentState!.validate()) return;
                if (selectedTxnId == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please select a POS transaction'), behavior: SnackBarBehavior.floating));
                  return;
                }
                setState(() => saving = true);
                try {
                  final dio = ref.read(dioProvider);
                  if (addressCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter a delivery address'), behavior: SnackBarBehavior.floating));
                    setState(() => saving = false);
                    return;
                  }
                  final body = <String, dynamic>{
                    'transaction': selectedTxnId,
                    'recipient_name': recipientCtrl.text,
                    'recipient_phone': phoneCtrl.text,
                    'delivery_address': addressCtrl.text,
                    'delivery_fee': feeCtrl.text.isNotEmpty ? feeCtrl.text : '0',
                    'notes': notesCtrl.text,
                  };
                  if (latValue.isNotEmpty) {
                    final lv = double.tryParse(latValue);
                    body['latitude'] = lv != null ? lv.toStringAsFixed(12) : latValue;
                  }
                  if (lngValue.isNotEmpty) {
                    final lv = double.tryParse(lngValue);
                    body['longitude'] = lv != null ? lv.toStringAsFixed(12) : lngValue;
                  }
                  await dio.post('/pharmacy-profile/deliveries/', data: body);
                  ref.invalidate(_deliveriesProvider);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Delivery created'), behavior: SnackBarBehavior.floating));
                  }
                } on DioException catch (e) {
                  setState(() => saving = false);
                  final detail = e.response?.data;
                  String msg = 'Error creating delivery';
                  if (detail is Map) {
                    msg = detail.entries.map((e) => '${e.key}: ${e.value is List ? (e.value as List).join(', ') : e.value}').join('\n');
                  } else if (detail != null) {
                    msg = '$detail';
                  }
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5)));
                } catch (e) {
                  setState(() => saving = false);
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
                }
              },
              icon: saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.local_shipping_rounded),
              label: const Text('Create Delivery'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ]),
        ),
      );
    }),
  );
}

// ════════════════════════════════════════════════════
// ASSIGN DRIVER DIALOG
// ════════════════════════════════════════════════════
void _showAssignDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> d) {
  String driverName = '${d['assigned_driver_name'] ?? ''}';
  int? driverId = d['assigned_to'];
  bool isManual = false;
  bool saving = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => StatefulBuilder(builder: (ctx, setState) {
      final cs = Theme.of(ctx).colorScheme;
      final staff = ref.watch(_staffProvider);

      return Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            const Icon(Icons.person_add_rounded, size: 22, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 10),
            const Text('Assign Driver', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text('Delivery to ${d['recipient_name'] ?? '#${d['id']}'}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),

          // Mode toggle
          Row(children: [
            _FilterChip(label: 'Staff', selected: !isManual, color: const Color(0xFF8B5CF6), onTap: () => setState(() => isManual = false)),
            const SizedBox(width: 8),
            _FilterChip(label: 'Manual', selected: isManual, color: const Color(0xFFF59E0B), onTap: () => setState(() { isManual = true; driverId = null; })),
          ]),
          const SizedBox(height: 14),

          if (isManual)
            TextField(
              decoration: const InputDecoration(labelText: 'Driver Name', isDense: true, prefixIcon: Icon(Icons.person_rounded, size: 18)),
              onChanged: (v) => driverName = v,
              controller: TextEditingController(text: driverName),
            )
          else
            staff.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Failed to load staff'),
              data: (staffList) => DropdownButtonFormField<int>(
                value: driverId,
                decoration: const InputDecoration(labelText: 'Select Staff', isDense: true, prefixIcon: Icon(Icons.people_rounded, size: 18)),
                items: staffList.map<DropdownMenuItem<int>>((s) => DropdownMenuItem(
                  value: s['id'] as int,
                  child: Text('${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim(), style: const TextStyle(fontSize: 13)),
                )).toList(),
                onChanged: (v) => setState(() { driverId = v; }),
              ),
            ),

          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: saving ? null : () async {
              if (!isManual && driverId == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Select a driver'), behavior: SnackBarBehavior.floating));
                return;
              }
              if (isManual && driverName.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter driver name'), behavior: SnackBarBehavior.floating));
                return;
              }
              setState(() => saving = true);
              try {
                final dio = ref.read(dioProvider);
                final body = <String, dynamic>{};
                if (isManual) {
                  body['assigned_driver_name'] = driverName;
                } else {
                  body['assigned_to'] = driverId;
                }
                // Auto-transition to assigned if pending
                if (d['status'] == 'pending') body['status'] = 'assigned';
                await dio.patch('/pharmacy-profile/deliveries/${d['id']}/', data: body);
                ref.invalidate(_deliveriesProvider);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Driver assigned'), behavior: SnackBarBehavior.floating));
                }
              } catch (e) {
                setState(() => saving = false);
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
              }
            },
            icon: saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded),
            label: const Text('Assign'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48), backgroundColor: const Color(0xFF8B5CF6)),
          ),
        ]),
      );
    }),
  );
}

// ════════════════════════════════════════════════════
// ACTIONS
// ════════════════════════════════════════════════════
void _updateStatus(BuildContext context, WidgetRef ref, Map<String, dynamic> d, String newStatus) async {
  try {
    await ref.read(dioProvider).post('/pharmacy-profile/deliveries/${d['id']}/update_status/', data: {'status': newStatus});
    ref.invalidate(_deliveriesProvider);
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to ${_statusLabels[newStatus]}'), behavior: SnackBarBehavior.floating));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
  }
}

void _confirmDelete(BuildContext context, WidgetRef ref, Map<String, dynamic> d) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Delete Delivery'),
      content: Text('Remove delivery to "${d['recipient_name'] ?? '#${d['id']}'}"? This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
          onPressed: () async {
            Navigator.pop(context);
            try {
              await ref.read(dioProvider).delete('/pharmacy-profile/deliveries/${d['id']}/');
              ref.invalidate(_deliveriesProvider);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery deleted'), behavior: SnackBarBehavior.floating));
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

// ════════════════════════════════════════════════════
// SHARED WIDGETS
// ════════════════════════════════════════════════════
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
        SizedBox(width: 85, child: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoChip(this.icon, this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Flexible(child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? color.withValues(alpha: 0.3) : cs.outlineVariant.withValues(alpha: 0.2)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: selected ? color : cs.onSurfaceVariant)),
      ),
    );
  }
}

class _MiniKPI extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _MiniKPI({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(10),
      color: color.withValues(alpha: 0.06),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7))),
      ]),
    ]),
  );
}
