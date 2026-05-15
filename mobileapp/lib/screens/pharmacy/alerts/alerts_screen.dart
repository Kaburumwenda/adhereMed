import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/api.dart';
import '../../../widgets/common.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════
final _searchProvider = StateProvider<String>((ref) => '');
final _typeFilterProvider = StateProvider<String>((ref) => '');
final _readFilterProvider = StateProvider<String>((ref) => '');

final _alertsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final params = <String, dynamic>{'page_size': 20, 'ordering': '-created_at'};
  final type = ref.watch(_typeFilterProvider);
  if (type.isNotEmpty) params['type'] = type;
  final read = ref.watch(_readFilterProvider);
  if (read == 'unread') params['is_read'] = false;
  if (read == 'read') params['is_read'] = true;
  final res = await dio.get('/notifications/', queryParameters: params);
  final data = res.data;
  final items = (data['results'] as List?) ?? (data is List ? data as List : []);
  final next = data is Map ? data['next']?.toString() : null;
  return {'items': items, 'next': next};
});

final _stockAlertsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final results = await Future.wait([
    dio.get('/inventory/stocks/low_stock/'),
    dio.get('/inventory/stocks/expiring_soon/', queryParameters: {'days': 90}),
  ]);
  final lowStock = (results[0].data is List ? results[0].data : (results[0].data?['results'] ?? [])) as List;
  final expiring = (results[1].data is List ? results[1].data : (results[1].data?['results'] ?? [])) as List;
  return {'low_stock': lowStock, 'expiring': expiring};
});

// ═══════════════════════════════════════════════════════════════════════════
//  TYPE HELPERS
// ═══════════════════════════════════════════════════════════════════════════
const _typeFilters = ['appointment', 'lab_result', 'prescription', 'billing', 'stock_alert', 'system'];
const _typeLabels = {
  'appointment': 'Appointment', 'lab_result': 'Lab Result', 'prescription': 'Prescription',
  'home_collection': 'Home Collection', 'billing': 'Billing', 'system': 'System',
  'dose_reminder': 'Dose Reminder', 'dose_missed': 'Dose Missed', 'escalation': 'Escalation',
  'teleconsult': 'Teleconsult', 'insurance_claim': 'Insurance', 'caregiver_update': 'Caregiver',
  'stock_alert': 'Stock Alert', 'consent': 'Consent',
};

Color _typeColor(String t) => switch (t) {
  'appointment' => const Color(0xFF6366F1),
  'lab_result' => const Color(0xFF8B5CF6),
  'prescription' => const Color(0xFF14B8A6),
  'home_collection' => const Color(0xFF06B6D4),
  'billing' => const Color(0xFFF59E0B),
  'system' => const Color(0xFF6B7280),
  'dose_reminder' => const Color(0xFF3B82F6),
  'dose_missed' => const Color(0xFFEF4444),
  'escalation' => const Color(0xFFEF4444),
  'stock_alert' => const Color(0xFFF97316),
  'insurance_claim' => const Color(0xFF8B5CF6),
  _ => const Color(0xFF94A3B8),
};

IconData _typeIcon(String t) => switch (t) {
  'appointment' => Icons.calendar_month_rounded,
  'lab_result' => Icons.science_rounded,
  'prescription' => Icons.medication_rounded,
  'home_collection' => Icons.local_shipping_rounded,
  'billing' => Icons.receipt_rounded,
  'system' => Icons.settings_rounded,
  'dose_reminder' => Icons.alarm_rounded,
  'dose_missed' => Icons.alarm_off_rounded,
  'escalation' => Icons.priority_high_rounded,
  'teleconsult' => Icons.videocam_rounded,
  'insurance_claim' => Icons.shield_rounded,
  'caregiver_update' => Icons.people_rounded,
  'stock_alert' => Icons.inventory_rounded,
  'consent' => Icons.verified_user_rounded,
  _ => Icons.notifications_rounded,
};

// ═══════════════════════════════════════════════════════════════════════════
//  SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});
  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final typeFilter = ref.watch(_typeFilterProvider);
    final readFilter = ref.watch(_readFilterProvider);
    final stockData = ref.watch(_stockAlertsProvider);

    // Badge counts
    final stockBadge = stockData.whenOrNull(data: (d) {
      final low = (d['low_stock'] as List).length;
      final exp = (d['expiring'] as List).length;
      return low + exp;
    }) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_rounded, size: 20),
            tooltip: 'Scan Inventory',
            onPressed: () async {
              try {
                await ref.read(dioProvider).post('/notifications/scan-inventory/', data: {'days': 30});
                ref.invalidate(_alertsProvider);
                ref.invalidate(_stockAlertsProvider);
                if (mounted) _snack(context, 'Inventory scan triggered', const Color(0xFF10B981));
              } on DioException catch (e) { if (mounted) _snackErr(context, e); }
            },
          ),
          IconButton(
            icon: const Icon(Icons.done_all_rounded, size: 20),
            tooltip: 'Mark All Read',
            onPressed: () async {
              try {
                final res = await ref.read(dioProvider).post('/notifications/mark_all_read/');
                ref.invalidate(_alertsProvider);
                if (mounted) _snack(context, '${res.data['updated'] ?? 0} marked as read', const Color(0xFF3B82F6));
              } catch (_) { if (mounted) _snack(context, 'Failed', Colors.red); }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            const Tab(text: 'Notifications'),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Stock Alerts'),
              if (stockBadge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                  child: Text('$stockBadge', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ])),
          ],
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          indicatorSize: TabBarIndicatorSize.label,
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ── Tab 1: Notifications ──
          _NotificationsTab(cs: cs, typeFilter: typeFilter, readFilter: readFilter),

          // ── Tab 2: Stock Alerts ──
          _StockAlertsTab(ref: ref),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  NOTIFICATIONS TAB (original content extracted)
// ═══════════════════════════════════════════════════════════════════════════
class _NotificationsTab extends ConsumerStatefulWidget {
  const _NotificationsTab({required this.cs, required this.typeFilter, required this.readFilter});
  final ColorScheme cs;
  final String typeFilter;
  final String readFilter;

  @override
  ConsumerState<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends ConsumerState<_NotificationsTab> {
  final _scrollCtrl = ScrollController();
  Timer? _debounce;
  List _items = [];
  String? _nextUrl;
  bool _loadingMore = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200 && !_loadingMore && _nextUrl != null) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_nextUrl == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final dio = ref.read(dioProvider);
      // Extract path from full URL - the next URL may be absolute
      final uri = Uri.parse(_nextUrl!);
      final path = uri.path.replaceFirst(RegExp(r'^/api'), '');
      final res = await dio.get(path, queryParameters: uri.queryParameters);
      final data = res.data;
      final newItems = (data['results'] as List?) ?? [];
      setState(() {
        _items.addAll(newItems);
        _nextUrl = data['next']?.toString();
        _loadingMore = false;
      });
    } catch (_) {
      setState(() => _loadingMore = false);
    }
  }

  List get _filtered {
    if (_search.isEmpty) return _items;
    final q = _search.toLowerCase();
    return _items.where((n) =>
      '${n['title'] ?? ''}'.toLowerCase().contains(q) ||
      '${n['message'] ?? ''}'.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final data = ref.watch(_alertsProvider);

    // Sync initial data from provider
    data.whenData((d) {
      if (_items.isEmpty || _items.length <= (d['items'] as List).length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _items = List.from(d['items'] as List);
              _nextUrl = d['next']?.toString();
            });
          }
        });
      }
    });

    return Column(children: [
      // ── KPI row ──
      if (_items.isNotEmpty)
        Builder(builder: (_) {
          final unread = _items.where((n) => n['is_read'] != true).length;
          final today = _items.where((n) {
            try { return DateTime.parse(n['created_at']).day == DateTime.now().day; } catch (_) { return false; }
          }).length;
          final system = _items.where((n) => n['type'] == 'system').length;
          return _KpiRow(items: [
            _Kpi('Loaded', _items.length, const Color(0xFF6366F1)),
            _Kpi('Unread', unread, const Color(0xFFF59E0B)),
            _Kpi('Today', today, const Color(0xFF3B82F6)),
            _Kpi('System', system, const Color(0xFF6B7280)),
          ]);
        }),

      // ── Search + filters ──
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Row(children: [
          Expanded(child: TextField(
            decoration: InputDecoration(
              hintText: 'Search alerts...', prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true, filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            style: const TextStyle(fontSize: 14),
            onChanged: (v) { _debounce?.cancel(); _debounce = Timer(const Duration(milliseconds: 300), () { if (mounted) setState(() => _search = v); }); },
          )),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Badge(isLabelVisible: widget.typeFilter.isNotEmpty,
              child: Icon(Icons.category_rounded, size: 20, color: widget.typeFilter.isNotEmpty ? cs.primary : null)),
            onSelected: (v) { ref.read(_typeFilterProvider.notifier).state = v; setState(() => _items = []); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('All Types')),
              ..._typeFilters.map((t) => PopupMenuItem(value: t, child: Row(children: [
                Icon(_typeIcon(t), size: 16, color: _typeColor(t)), const SizedBox(width: 8),
                Text(_typeLabels[t] ?? t)]))),
            ],
          ),
          PopupMenuButton<String>(
            icon: Badge(isLabelVisible: widget.readFilter.isNotEmpty,
              child: Icon(Icons.filter_list_rounded, size: 20, color: widget.readFilter.isNotEmpty ? cs.primary : null)),
            onSelected: (v) { ref.read(_readFilterProvider.notifier).state = v; setState(() => _items = []); },
            itemBuilder: (_) => const [
              PopupMenuItem(value: '', child: Text('All')),
              PopupMenuItem(value: 'unread', child: Text('Unread')),
              PopupMenuItem(value: 'read', child: Text('Read')),
            ],
          ),
        ]),
      ),
      const SizedBox(height: 4),
      const Divider(height: 1),

      // ── List ──
      Expanded(child: data.when(
        loading: () => _items.isEmpty ? const LoadingShimmer() : _buildList(),
        error: (e, _) => _items.isEmpty
            ? ErrorRetry(message: 'Failed to load', onRetry: () { setState(() => _items = []); ref.invalidate(_alertsProvider); })
            : _buildList(),
        data: (_) => _buildList(),
      )),
    ]);
  }

  Widget _buildList() {
    final items = _filtered;
    if (items.isEmpty) return const EmptyState(icon: Icons.notifications_off_rounded, title: 'No alerts');
    return RefreshIndicator(
      onRefresh: () async { setState(() => _items = []); ref.invalidate(_alertsProvider); },
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: items.length + (_loadingMore || _nextUrl != null ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          return _AlertCard(alert: items[i], ref: ref)
            .animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: (30 * (i % 20)).clamp(0, 300))).slideX(begin: 0.03, end: 0);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  STOCK ALERTS TAB
// ═══════════════════════════════════════════════════════════════════════════
class _StockAlertsTab extends ConsumerWidget {
  const _StockAlertsTab({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = ref.watch(_stockAlertsProvider);

    return data.when(
      loading: () => const LoadingShimmer(),
      error: (e, _) => ErrorRetry(message: 'Failed to load stock alerts', onRetry: () => ref.invalidate(_stockAlertsProvider)),
      data: (d) {
        final lowStock = List<Map<String, dynamic>>.from(d['low_stock'] as List);
        final expiring = List<Map<String, dynamic>>.from(d['expiring'] as List);

        if (lowStock.isEmpty && expiring.isEmpty) {
          return const EmptyState(icon: Icons.check_circle_outline_rounded, title: 'No stock alerts', subtitle: 'All stock levels and expiry dates look good.');
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_stockAlertsProvider),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 80), children: [
            // ── KPI row ──
            _KpiRow(items: [
              _Kpi('Low Stock', lowStock.length, Colors.orange.shade600),
              _Kpi('Expiring', expiring.length, const Color(0xFFEF4444)),
            ]),

            // ── Low Stock Section ──
            if (lowStock.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                child: Row(children: [
                  Icon(Icons.trending_down_rounded, size: 18, color: Colors.orange.shade600),
                  const SizedBox(width: 8),
                  Text('Low Stock (${lowStock.length})',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: cs.onSurface)),
                ]),
              ),
              ...lowStock.map((item) => _StockAlertCard(
                name: item['medication_name']?.toString() ?? '',
                subtitle: 'Qty: ${item['total_quantity'] ?? 0}  •  Reorder: ${item['reorder_level'] ?? 0}',
                icon: Icons.inventory_2_rounded,
                color: Colors.orange.shade600,
                trailing: '${item['total_quantity'] ?? 0} left',
                isUrgent: (item['total_quantity'] ?? 0) == 0,
                cs: cs,
                isDark: isDark,
              )),
            ],

            // ── Expiring Section ──
            if (expiring.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
                child: Row(children: [
                  const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Text('Expiring Soon (${expiring.length})',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: cs.onSurface)),
                ]),
              ),
              ...expiring.map((batch) {
                final expiryDate = DateTime.tryParse(batch['expiry_date']?.toString() ?? '');
                final daysLeft = expiryDate != null ? expiryDate.difference(DateTime.now()).inDays : 0;
                final isExpired = daysLeft < 0;
                return _StockAlertCard(
                  name: batch['stock_name']?.toString() ?? 'Batch ${batch['batch_number'] ?? ''}',
                  subtitle: 'Batch: ${batch['batch_number'] ?? '-'}  •  Qty: ${batch['quantity_remaining'] ?? 0}',
                  icon: isExpired ? Icons.error_rounded : Icons.warning_amber_rounded,
                  color: isExpired ? Colors.red.shade700 : const Color(0xFFF59E0B),
                  trailing: isExpired ? 'EXPIRED' : '${daysLeft}d left',
                  isUrgent: isExpired,
                  cs: cs,
                  isDark: isDark,
                );
              }),
            ],
          ]),
        );
      },
    );
  }
}

class _StockAlertCard extends StatelessWidget {
  const _StockAlertCard({required this.name, required this.subtitle, required this.icon, required this.color, required this.trailing, required this.isUrgent, required this.cs, required this.isDark});
  final String name, subtitle, trailing;
  final IconData icon;
  final Color color;
  final bool isUrgent, isDark;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: isUrgent ? color.withValues(alpha: 0.06) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isUrgent ? color.withValues(alpha: 0.3) : cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(trailing, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
        ]),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.03, end: 0);
  }
}

// ── Alert Card ──
class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.ref});
  final dynamic alert;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final type = alert['type'] ?? 'system';
    final tc = _typeColor(type);
    final read = alert['is_read'] == true;
    String timeStr = '';
    try { timeStr = timeago.format(DateTime.parse(alert['created_at'])); } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: read ? null : tc.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showAlertDetail(context, alert, ref),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: read ? cs.outlineVariant.withValues(alpha: 0.5) : tc.withValues(alpha: 0.3)),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: tc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(_typeIcon(type), color: tc, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(alert['title'] ?? 'Notification',
                  style: TextStyle(fontWeight: read ? FontWeight.w500 : FontWeight.w700, fontSize: 14))),
                if (!read) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: tc.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text('NEW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: tc)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(alert['message'] ?? '', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.4),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: tc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(_typeLabels[type] ?? type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: tc)),
                ),
                const Spacer(),
                Text(timeStr, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                if (!read) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      try {
                        await ref.read(dioProvider).post('/notifications/${alert['id']}/mark_read/');
                        ref.invalidate(_alertsProvider);
                      } catch (_) {}
                    },
                    child: Icon(Icons.check_circle_outline_rounded, size: 20, color: tc),
                  ),
                ],
              ]),
            ])),
          ]),
        ),
      ),
    );
  }
}

void _showAlertDetail(BuildContext context, dynamic alert, WidgetRef ref) {
  final cs = Theme.of(context).colorScheme;
  final type = alert['type'] ?? 'system';
  final tc = _typeColor(type);
  final read = alert['is_read'] == true;

  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.55, maxChildSize: 0.85, minChildSize: 0.3,
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
              Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: tc.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(_typeIcon(type), size: 28, color: tc)),
              const SizedBox(height: 12),
              Text(alert['title'] ?? '', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.onSurface), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: tc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(_typeLabels[type] ?? type, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tc)),
              ),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(alert['message'] ?? '', style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.5)),
            const SizedBox(height: 16),
            if (alert['created_at'] != null)
              _InfoTile(icon: Icons.schedule_rounded, label: 'Time', value: _fmtDateTime(alert['created_at']?.toString())),
            if (!read)
              Padding(padding: const EdgeInsets.only(top: 16), child: FilledButton.icon(
                onPressed: () async {
                  try {
                    await ref.read(dioProvider).post('/notifications/${alert['id']}/mark_read/');
                    ref.invalidate(_alertsProvider);
                    if (context.mounted) { Navigator.pop(ctx); _snack(context, 'Marked as read', tc); }
                  } catch (_) {}
                },
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Mark as Read'),
                style: FilledButton.styleFrom(backgroundColor: tc,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              )),
          ])),
        ]),
      ),
    ),
  );
  // Auto-mark read on open
  if (!read) {
    ref.read(dioProvider).post('/notifications/${alert['id']}/mark_read/').then((_) => ref.invalidate(_alertsProvider)).catchError((_) {});
  }
}

String _fmtDateTime(String? d) {
  if (d == null || d.isEmpty) return '';
  try { return DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(d)); } catch (_) { return d; }
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
  const _KpiRow({required this.items});
  final List<_Kpi> items;
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: items.map((k) => Expanded(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(color: k.color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: k.color.withValues(alpha: 0.2))),
      child: Column(children: [
        Text('${k.value}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: k.color)),
        const SizedBox(height: 2),
        Text(k.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: k.color.withValues(alpha: 0.8)),
          textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ))).toList()),
  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
}

class _Kpi { const _Kpi(this.label, this.value, this.color); final String label; final int value; final Color color; }

void _snack(BuildContext context, String msg, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, backgroundColor: color));
}

void _snackErr(BuildContext context, DioException e) {
  final d = e.response?.data;
  String msg = 'Request failed';
  if (d is Map) { msg = d.entries.map((e) => '${e.key}: ${e.value is List ? (e.value as List).join(', ') : e.value}').join('\n'); }
  else if (d is String && d.isNotEmpty) { msg = d; }
  _snack(context, msg, Colors.red);
}
