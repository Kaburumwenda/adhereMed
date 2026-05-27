import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/api.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/branch_provider.dart';
import '../../../widgets/common.dart';

String _fmtMoney(dynamic v) {
  final n = double.tryParse('$v') ?? 0;
  return NumberFormat.currency(symbol: 'KES ', decimalDigits: 0).format(n);
}

String _fmtTime(String? t) {
  if (t == null || t.isEmpty) return '';
  final d = DateTime.tryParse(t);
  if (d == null) return '';
  return DateFormat('MMM d, HH:mm').format(d.toLocal());
}

class ParkedSalesScreen extends ConsumerStatefulWidget {
  const ParkedSalesScreen({super.key});
  @override
  ConsumerState<ParkedSalesScreen> createState() => _ParkedSalesScreenState();
}

class _ParkedSalesScreenState extends ConsumerState<ParkedSalesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  String _search = '';
  String _filter = 'all'; // all, mine

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final role = ref.read(authProvider).user?.role ?? '';
      final params = <String, dynamic>{'page_size': 200};

      // Branch filter for soft-assign roles
      if (const {'cashier', 'pharmacist', 'pharmacy_tech'}.contains(role)) {
        final branchId = ref.read(branchProvider).currentBranchId;
        if (branchId != null) params['branch'] = branchId;
      }
      if (_filter == 'mine') params['mine'] = '1';

      final res = await dio.get('/pos/parked-sales/', queryParameters: params);
      final data = res.data;
      final list = data is List ? data : (data?['results'] as List?) ?? [];
      setState(() {
        _items = List<Map<String, dynamic>>.from(list);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
      _snack('Failed to load parked sales', isError: true);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _items;
    final q = _search.toLowerCase();
    return _items.where((p) {
      final num = (p['park_number'] ?? '').toString().toLowerCase();
      final name = (p['customer_name'] ?? '').toString().toLowerCase();
      final phone = (p['customer_phone'] ?? '').toString().toLowerCase();
      return num.contains(q) || name.contains(q) || phone.contains(q);
    }).toList();
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? Colors.red.shade700 : null,
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _resume(Map<String, dynamic> p) async {
    // Delete from server then navigate to POS with data
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/pos/parked-sales/${p['id']}/');
    } catch (_) {}

    if (!mounted) return;
    // Pass parked sale via GoRouter extra
    context.go('/pos', extra: {'resume_parked': p});
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete parked sale?'),
        content: Text(
            '${p['park_number']} · ${p['customer_name'] ?? 'Walk-in'} · ${_fmtMoney(p['total'])}.\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/pos/parked-sales/${p['id']}/');
      setState(() => _items.removeWhere((x) => x['id'] == p['id']));
      _snack('Parked sale deleted');
    } catch (_) {
      _snack('Failed to delete', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.pause_circle_rounded, color: Colors.orange.shade700, size: 24),
          const SizedBox(width: 8),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Parked Sales', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('Sales on hold', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ]),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          IconButton(
            onPressed: () => context.go('/pos'),
            icon: const Icon(Icons.point_of_sale_rounded),
            tooltip: 'Go to POS',
          ),
        ],
      ),
      body: Column(children: [
        // Expiry alert banner
        Container(
          margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade600.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(Icons.timer_outlined, size: 18, color: Colors.amber.shade800),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Parked sales expire after 48 hours and will be automatically removed.',
                style: TextStyle(fontSize: 11.5, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
              ),
            ),
          ]),
        ),
        // Filter row
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
          child: Row(children: [
            // Search
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search park #, customer...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // All / Mine toggle
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('All', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: 'mine', label: Text('Mine', style: TextStyle(fontSize: 11))),
              ],
              selected: {_filter},
              onSelectionChanged: (v) {
                setState(() => _filter = v.first);
                _load();
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        // Content
        Expanded(
          child: _loading
              ? const Center(child: LoadingShimmer(lines: 5))
              : filtered.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.inbox_rounded, size: 64, color: cs.outlineVariant),
                        const SizedBox(height: 12),
                        Text('No parked sales', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text('Sales on hold will appear here', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 80),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _buildCard(filtered[i], cs, isDark, i),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _buildCard(Map<String, dynamic> p, ColorScheme cs, bool isDark, int index) {
    final parkNum = p['park_number'] ?? '#${p['id']}';
    final name = (p['customer_name'] ?? 'Walk-in').toString();
    final phone = (p['customer_phone'] ?? '').toString();
    final cashier = (p['cashier_name'] ?? '').toString();
    final createdAt = _fmtTime((p['created_at'] ?? '').toString());
    final items = (p['items'] as List?) ?? [];
    final total = p['total'];

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header: park number + item count badge
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(parkNum, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.orange.shade800)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${items.length} items', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cs.primary)),
            ),
          ]),
          const SizedBox(height: 10),
          // Customer + cashier
          Row(children: [
            Icon(Icons.person_rounded, size: 14, color: cs.primary),
            const SizedBox(width: 6),
            Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            if (phone.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text('· $phone', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ]),
          if (cashier.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Icon(Icons.badge_rounded, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(cashier, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ]),
            ),
          if (createdAt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Icon(Icons.access_time_rounded, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(createdAt, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ]),
            ),
          const SizedBox(height: 10),
          // Items preview
          ...items.take(4).map((it) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(children: [
              Expanded(
                child: Text('${it['quantity']} × ${it['name'] ?? 'Item'}',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis),
              ),
              Text(_fmtMoney((double.tryParse('${it['selling_price']}') ?? 0) * (int.tryParse('${it['quantity']}') ?? 1)),
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ]),
          )),
          if (items.length > 4)
            Text('+ ${items.length - 4} more item(s)…', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          const Divider(height: 20),
          // Total + actions
          Row(children: [
            Text('Total', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const Spacer(),
            Text(_fmtMoney(total), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.primary)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _resume(p),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Resume'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              width: 40,
              child: IconButton.filled(
                onPressed: () => _delete(p),
                icon: const Icon(Icons.delete_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.red,
                ),
              ),
            ),
          ]),
        ]),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms).slideY(begin: 0.05);
  }
}
