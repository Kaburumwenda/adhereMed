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

// ── Standard Rx ──
final _rxSearchProvider = StateProvider<String>((ref) => '');
final _rxStatusProvider = StateProvider<String>((ref) => '');
final _rxProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final params = <String, dynamic>{'page_size': 200, 'ordering': '-created_at'};
  final status = ref.watch(_rxStatusProvider);
  if (status.isNotEmpty) params['status'] = status;
  final res = await dio.get('/prescriptions/', queryParameters: params);
  final items = (res.data['results'] as List?) ?? (res.data is List ? res.data as List : []);
  final q = ref.watch(_rxSearchProvider).toLowerCase();
  if (q.isEmpty) return items;
  return items.where((r) =>
    '${r['patient_name'] ?? ''}'.toLowerCase().contains(q) ||
    '${r['doctor_name'] ?? ''}'.toLowerCase().contains(q) ||
    '${r['diagnosis'] ?? ''}'.toLowerCase().contains(q)
  ).toList();
});

// ── Pharmacy Rx ──
final _pharmSearchProvider = StateProvider<String>((ref) => '');
final _pharmStatusProvider = StateProvider<String>((ref) => '');
final _pharmProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final params = <String, dynamic>{'page_size': 200, 'ordering': '-created_at'};
  final status = ref.watch(_pharmStatusProvider);
  if (status.isNotEmpty) params['status'] = status;
  final res = await dio.get('/prescriptions/pharmacy-rx/', queryParameters: params);
  final items = (res.data['results'] as List?) ?? (res.data is List ? res.data as List : []);
  final q = ref.watch(_pharmSearchProvider).toLowerCase();
  if (q.isEmpty) return items;
  return items.where((r) =>
    '${r['patient_name'] ?? ''}'.toLowerCase().contains(q) ||
    '${r['patient_phone'] ?? ''}'.toLowerCase().contains(q)
  ).toList();
});

// ── Patients for autocomplete ──
final _patientsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/patients/', queryParameters: {'page_size': 500});
  return (res.data['results'] as List?) ?? (res.data is List ? res.data as List : []);
});

// ═══════════════════════════════════════════════════════════════════════════
//  STATUS HELPERS
// ═══════════════════════════════════════════════════════════════════════════
const _rxStatuses = ['active', 'sent_to_exchange', 'dispensed', 'cancelled'];
const _rxStatusLabels = {
  'active': 'Active', 'sent_to_exchange': 'Sent to Exchange',
  'dispensed': 'Dispensed', 'cancelled': 'Cancelled',
};

const _pharmStatuses = ['active', 'dispensed', 'cancelled'];
const _pharmStatusLabels = {
  'active': 'Active', 'dispensed': 'Dispensed', 'cancelled': 'Cancelled',
};

Color _rxStatusColor(String s) => switch (s) {
  'active' => const Color(0xFF0EA5E9),
  'sent_to_exchange' => const Color(0xFF8B5CF6),
  'dispensed' => const Color(0xFF10B981),
  'cancelled' => const Color(0xFFEF4444),
  _ => const Color(0xFF94A3B8),
};

Color _pharmStatusColor(String s) => switch (s) {
  'active' => const Color(0xFF0EA5E9),
  'dispensed' => const Color(0xFF10B981),
  'cancelled' => const Color(0xFF64748B),
  _ => const Color(0xFF94A3B8),
};

IconData _rxStatusIcon(String s) => switch (s) {
  'active' => Icons.pending_actions_rounded,
  'sent_to_exchange' => Icons.send_rounded,
  'dispensed' => Icons.check_circle_rounded,
  'cancelled' => Icons.cancel_rounded,
  _ => Icons.help_outline_rounded,
};

IconData _pharmStatusIcon(String s) => switch (s) {
  'active' => Icons.pending_actions_rounded,
  'dispensed' => Icons.check_circle_rounded,
  'cancelled' => Icons.cancel_rounded,
  _ => Icons.help_outline_rounded,
};

String _fmtDate(String? d) {
  if (d == null || d.isEmpty) return '';
  try { return DateFormat('MMM d, yyyy').format(DateTime.parse(d)); } catch (_) { return d; }
}

String _fmtDateTime(String? d) {
  if (d == null || d.isEmpty) return '';
  try { return DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(d)); } catch (_) { return d; }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MAIN SCREEN — TABBED
// ═══════════════════════════════════════════════════════════════════════════
class PrescriptionsScreen extends ConsumerStatefulWidget {
  const PrescriptionsScreen({super.key});
  @override
  ConsumerState<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends ConsumerState<PrescriptionsScreen> with TickerProviderStateMixin {
  late final TabController _tabCtrl;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: 1);
    _currentTab = 1;
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() => _currentTab = _tabCtrl.index);
    });
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescriptions', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: 'Standard Rx'),
            Tab(text: 'Pharmacy Rx'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_currentTab == 0) {
            _showCreateRxDialog(context, ref);
          } else {
            _showCreatePharmRxDialog(context, ref);
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(_currentTab == 0 ? 'New Rx' : 'Walk-in Rx'),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _StandardRxTab(),
          _PharmacyRxTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 1: STANDARD RX
// ═══════════════════════════════════════════════════════════════════════════
class _StandardRxTab extends ConsumerStatefulWidget {
  const _StandardRxTab();
  @override
  ConsumerState<_StandardRxTab> createState() => _StandardRxTabState();
}

class _StandardRxTabState extends ConsumerState<_StandardRxTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Timer? _debounce;

  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final data = ref.watch(_rxProvider);
    final statusFilter = ref.watch(_rxStatusProvider);

    return Column(
      children: [
        // ── Search + Filter bar ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search patient, doctor...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 300), () => ref.read(_rxSearchProvider.notifier).state = v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Badge(
                  isLabelVisible: statusFilter.isNotEmpty,
                  child: Icon(Icons.filter_list_rounded, color: statusFilter.isNotEmpty ? cs.primary : null),
                ),
                onSelected: (v) => ref.read(_rxStatusProvider.notifier).state = v,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: '', child: Text('All Statuses')),
                  ..._rxStatuses.map((s) => PopupMenuItem(
                    value: s,
                    child: Row(children: [
                      Icon(_rxStatusIcon(s), size: 16, color: _rxStatusColor(s)),
                      const SizedBox(width: 8),
                      Text(_rxStatusLabels[s] ?? s),
                    ]),
                  )),
                ],
              ),
            ],
          ),
        ),

        // ── KPI Summary ──
        data.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) => _KpiRow(
            items: [
              _Kpi('Total', items.length, const Color(0xFF6366F1)),
              _Kpi('Active', items.where((r) => r['status'] == 'active').length, const Color(0xFF0EA5E9)),
              _Kpi('Dispensed', items.where((r) => r['status'] == 'dispensed').length, const Color(0xFF10B981)),
              _Kpi('Cancelled', items.where((r) => r['status'] == 'cancelled').length, const Color(0xFFEF4444)),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── List ──
        Expanded(
          child: data.when(
            loading: () => const LoadingShimmer(),
            error: (e, _) => ErrorRetry(message: 'Failed to load prescriptions', onRetry: () => ref.invalidate(_rxProvider)),
            data: (items) {
              if (items.isEmpty) return const EmptyState(icon: Icons.medication_rounded, title: 'No prescriptions');
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(_rxProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _StandardRxCard(rx: items[i], ref: ref)
                    .animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: (50 * i).clamp(0, 500))).slideY(begin: 0.05, end: 0),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Standard Rx Card ──
class _StandardRxCard extends StatelessWidget {
  const _StandardRxCard({required this.rx, required this.ref});
  final dynamic rx;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = rx['status'] ?? 'active';
    final sc = _rxStatusColor(status);
    final items = (rx['items'] as List?) ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showRxDetail(context, rx, ref),
        onLongPress: () => _showRxActions(context, rx, ref),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: sc,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.medication_rounded, color: sc, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(rx['patient_name'] ?? 'Unknown Patient',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text('Dr. ${rx['doctor_name'] ?? 'N/A'}',
                                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        _StatusChip(label: _rxStatusLabels[status] ?? status, color: sc),
                      ],
                    ),
                    if ((rx['diagnosis'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        Icon(Icons.medical_information_rounded, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(child: Text(rx['diagnosis'],
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                    const SizedBox(height: 10),
                    Row(children: [
                      Icon(Icons.medication_liquid_rounded, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text('${items.length} item${items.length == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Icon(Icons.schedule_rounded, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(_fmtDate(rx['created_at']?.toString()),
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Standard Rx long-press actions ──
void _showRxActions(BuildContext context, dynamic rx, WidgetRef ref) {
  final status = rx['status'] ?? 'active';
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.visibility_rounded, color: Color(0xFF0EA5E9)),
              title: const Text('View Details'),
              onTap: () { Navigator.pop(ctx); _showRxDetail(context, rx, ref); },
            ),
            if (status == 'active') ...[
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: Color(0xFFF59E0B)),
                title: const Text('Edit'),
                onTap: () { Navigator.pop(ctx); _showEditRxDialog(context, ref, rx); },
              ),
              ListTile(
                leading: const Icon(Icons.send_rounded, color: Color(0xFF8B5CF6)),
                title: const Text('Send to Exchange'),
                onTap: () { Navigator.pop(ctx); _sendToExchange(context, ref, rx['id']); },
              ),
              ListTile(
                leading: const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444)),
                title: const Text('Cancel'),
                onTap: () { Navigator.pop(ctx); _cancelRx(context, ref, rx['id']); },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(ctx); _deleteRx(context, ref, rx['id']); },
            ),
          ],
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 2: PHARMACY RX (walk-in)
// ═══════════════════════════════════════════════════════════════════════════
class _PharmacyRxTab extends ConsumerStatefulWidget {
  const _PharmacyRxTab();
  @override
  ConsumerState<_PharmacyRxTab> createState() => _PharmacyRxTabState();
}

class _PharmacyRxTabState extends ConsumerState<_PharmacyRxTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Timer? _debounce;

  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final data = ref.watch(_pharmProvider);
    final statusFilter = ref.watch(_pharmStatusProvider);

    return Column(
      children: [
        // ── Search + Filter ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search patient, phone...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 300), () => ref.read(_pharmSearchProvider.notifier).state = v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Badge(
                  isLabelVisible: statusFilter.isNotEmpty,
                  child: Icon(Icons.filter_list_rounded, color: statusFilter.isNotEmpty ? cs.primary : null),
                ),
                onSelected: (v) => ref.read(_pharmStatusProvider.notifier).state = v,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: '', child: Text('All Statuses')),
                  ..._pharmStatuses.map((s) => PopupMenuItem(
                    value: s,
                    child: Row(children: [
                      Icon(_pharmStatusIcon(s), size: 16, color: _pharmStatusColor(s)),
                      const SizedBox(width: 8),
                      Text(_pharmStatusLabels[s] ?? s),
                    ]),
                  )),
                ],
              ),
            ],
          ),
        ),

        // ── KPI Summary ──
        data.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) {
            final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
            return _KpiRow(
              items: [
                _Kpi('Total', items.length, const Color(0xFF6366F1)),
                _Kpi('Active', items.where((r) => r['status'] == 'active').length, const Color(0xFF0EA5E9)),
                _Kpi('Dispensed', items.where((r) => r['status'] == 'dispensed').length, const Color(0xFF10B981)),
                _Kpi("Today's", items.where((r) => (r['created_at'] ?? '').toString().startsWith(today)).length, const Color(0xFFF59E0B)),
              ],
            );
          },
        ),

        const Divider(height: 1),

        // ── List ──
        Expanded(
          child: data.when(
            loading: () => const LoadingShimmer(),
            error: (e, _) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_pharmProvider)),
            data: (items) {
              if (items.isEmpty) return const EmptyState(icon: Icons.local_pharmacy_rounded, title: 'No pharmacy prescriptions');
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(_pharmProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _PharmRxCard(rx: items[i], ref: ref)
                    .animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: (50 * i).clamp(0, 500))).slideY(begin: 0.05, end: 0),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Pharmacy Rx Card ──
class _PharmRxCard extends StatelessWidget {
  const _PharmRxCard({required this.rx, required this.ref});
  final dynamic rx;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = rx['status'] ?? 'active';
    final sc = _pharmStatusColor(status);
    final items = (rx['items'] as List?) ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showPharmRxDetail(context, rx, ref),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 5, height: 100,
                decoration: BoxDecoration(
                  color: sc,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(rx['patient_name'] ?? 'Walk-in #${rx['id']}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                        _StatusChip(label: _pharmStatusLabels[status] ?? status, color: sc),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        if ((rx['patient_phone'] ?? '').toString().isNotEmpty) ...[
                          Icon(Icons.phone_rounded, size: 13, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(rx['patient_phone'], style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          const SizedBox(width: 16),
                        ],
                        Icon(Icons.medication_liquid_rounded, size: 13, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('${items.length} item${items.length == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        const Spacer(),
                        Text(_fmtDate(rx['created_at']?.toString()),
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      ]),
                      if (status == 'active') ...[
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          _ActionMiniBtn(icon: Icons.check_circle_rounded, label: 'Dispense',
                            color: const Color(0xFF10B981),
                            onTap: () => _updatePharmStatus(context, ref, rx['id'], 'dispensed')),
                          const SizedBox(width: 8),
                          _ActionMiniBtn(icon: Icons.cancel_rounded, label: 'Cancel',
                            color: const Color(0xFFEF4444),
                            onTap: () => _updatePharmStatus(context, ref, rx['id'], 'cancelled')),
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.items});
  final List<_Kpi> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: items.map((k) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: k.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: k.color.withValues(alpha: 0.2)),
            ),
            child: Column(children: [
              Text('${k.value}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: k.color)),
              const SizedBox(height: 2),
              Text(k.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: k.color.withValues(alpha: 0.8)),
                textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        )).toList(),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }
}

class _Kpi {
  const _Kpi(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

class _ActionMiniBtn extends StatelessWidget {
  const _ActionMiniBtn({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  STANDARD RX — DETAIL DIALOG
// ═══════════════════════════════════════════════════════════════════════════
void _showRxDetail(BuildContext context, dynamic rx, WidgetRef ref) {
  final cs = Theme.of(context).colorScheme;
  final status = rx['status'] ?? 'active';
  final sc = _rxStatusColor(status);
  final items = (rx['items'] as List?) ?? [];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: EdgeInsets.zero,
          children: [
            // ── Hero header ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [sc.withValues(alpha: 0.15), sc.withValues(alpha: 0.03)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(Icons.medication_rounded, size: 32, color: sc),
                ),
                const SizedBox(height: 12),
                Text('Prescription #${rx['id']}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cs.onSurface)),
                const SizedBox(height: 6),
                _StatusChip(label: _rxStatusLabels[status] ?? status, color: sc),
              ]),
            ),

            // ── Info grid ──
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoTile(icon: Icons.person_rounded, label: 'Patient', value: rx['patient_name'] ?? 'N/A'),
                  _InfoTile(icon: Icons.local_hospital_rounded, label: 'Doctor', value: 'Dr. ${rx['doctor_name'] ?? 'N/A'}'),
                  if ((rx['diagnosis'] ?? '').toString().isNotEmpty)
                    _InfoTile(icon: Icons.medical_information_rounded, label: 'Diagnosis', value: rx['diagnosis']),
                  _InfoTile(icon: Icons.calendar_today_rounded, label: 'Date', value: _fmtDateTime(rx['created_at']?.toString())),
                  if ((rx['notes'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFD43B).withValues(alpha: 0.3)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.note_rounded, size: 16, color: Color(0xFF92400E)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(rx['notes'], style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)))),
                      ]),
                    ),
                  ],

                  // ── Items ──
                  const SizedBox(height: 20),
                  Text('Medications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
                  const SizedBox(height: 10),
                  if (items.isEmpty)
                    Center(child: Text('No items', style: TextStyle(color: cs.onSurfaceVariant)))
                  else
                    ...items.asMap().entries.map((e) => _MedicationCard(
                      index: e.key + 1, item: e.value,
                      showQuantity: true, showRefills: true, showInstructions: true,
                    )),

                  // ── Actions ──
                  if (status == 'active') ...[
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _sendToExchange(ctx, ref, rx['id']),
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: const Text('Send to Exchange'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _cancelRx(ctx, ref, rx['id']),
                          icon: const Icon(Icons.cancel_rounded, size: 18),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Send to Exchange ──
Future<void> _sendToExchange(BuildContext context, WidgetRef ref, int id) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Send to Exchange?'),
      content: const Text('This will send the prescription to the exchange network for quoting.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    final dio = ref.read(dioProvider);
    await dio.post('/prescriptions/$id/send_to_exchange/');
    ref.invalidate(_rxProvider);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sent to exchange successfully'), behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF10B981),
      ));
    }
  } on DioException catch (e) {
    if (context.mounted) {
      final msg = _extractError(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red));
    }
  }
}

// ── Cancel Rx ──
Future<void> _cancelRx(BuildContext context, WidgetRef ref, int id) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancel Prescription?'),
      content: const Text('This action cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Cancel Rx'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    final dio = ref.read(dioProvider);
    await dio.patch('/prescriptions/$id/', data: {'status': 'cancelled'});
    ref.invalidate(_rxProvider);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prescription cancelled'), behavior: SnackBarBehavior.floating));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to cancel'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PHARMACY RX — DETAIL DIALOG
// ═══════════════════════════════════════════════════════════════════════════
void _showPharmRxDetail(BuildContext context, dynamic rx, WidgetRef ref) {
  final cs = Theme.of(context).colorScheme;
  final status = rx['status'] ?? 'active';
  final sc = _pharmStatusColor(status);
  final items = (rx['items'] as List?) ?? [];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: EdgeInsets.zero,
          children: [
            // ── Hero header ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [sc.withValues(alpha: 0.15), sc.withValues(alpha: 0.03)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(Icons.local_pharmacy_rounded, size: 32, color: sc),
                ),
                const SizedBox(height: 12),
                Text(rx['patient_name'] ?? 'Walk-in Rx #${rx['id']}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cs.onSurface)),
                const SizedBox(height: 6),
                _StatusChip(label: _pharmStatusLabels[status] ?? status, color: sc),
              ]),
            ),

            // ── Info ──
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoTile(icon: Icons.person_rounded, label: 'Patient', value: rx['patient_name'] ?? 'N/A'),
                  if ((rx['patient_phone'] ?? '').toString().isNotEmpty)
                    _InfoTile(icon: Icons.phone_rounded, label: 'Phone', value: rx['patient_phone']),
                  if ((rx['pharmacist_name'] ?? '').toString().isNotEmpty)
                    _InfoTile(icon: Icons.badge_rounded, label: 'Pharmacist', value: rx['pharmacist_name']),
                  _InfoTile(icon: Icons.calendar_today_rounded, label: 'Created', value: _fmtDateTime(rx['created_at']?.toString())),
                  if ((rx['updated_at'] ?? '').toString().isNotEmpty)
                    _InfoTile(icon: Icons.update_rounded, label: 'Updated', value: _fmtDateTime(rx['updated_at']?.toString())),

                  if ((rx['notes'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.2)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.note_rounded, size: 16, color: Color(0xFF0369A1)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(rx['notes'], style: const TextStyle(fontSize: 13, color: Color(0xFF0369A1)))),
                      ]),
                    ),
                  ],

                  // ── Items ──
                  const SizedBox(height: 20),
                  Text('Medications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
                  const SizedBox(height: 10),
                  if (items.isEmpty)
                    Center(child: Text('No items', style: TextStyle(color: cs.onSurfaceVariant)))
                  else
                    ...items.asMap().entries.map((e) => _MedicationCard(
                      index: e.key + 1, item: e.value,
                      showQuantity: true, showInstructions: true,
                    )),

                  // ── Actions ──
                  if (status == 'active') ...[
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _updatePharmStatus(context, ref, rx['id'], 'dispensed');
                          },
                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                          label: const Text('Mark Dispensed'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _updatePharmStatus(context, ref, rx['id'], 'cancelled');
                          },
                          icon: const Icon(Icons.cancel_rounded, size: 18),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Update Pharmacy Rx Status ──
Future<void> _updatePharmStatus(BuildContext context, WidgetRef ref, int id, String status) async {
  final label = status == 'dispensed' ? 'Dispense' : 'Cancel';
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('$label this prescription?'),
      content: Text(status == 'dispensed'
        ? 'Mark as dispensed — patient has received their medication.'
        : 'Cancel this prescription. This action cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: status == 'dispensed' ? const Color(0xFF10B981) : Colors.red),
          child: Text(label),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    final dio = ref.read(dioProvider);
    await dio.patch('/prescriptions/pharmacy-rx/$id/', data: {'status': status});
    ref.invalidate(_pharmProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Prescription ${status == 'dispensed' ? 'dispensed' : 'cancelled'}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: status == 'dispensed' ? const Color(0xFF10B981) : Colors.red,
      ));
    }
  } on DioException catch (e) {
    if (context.mounted) {
      final msg = _extractError(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CREATE STANDARD RX DIALOG
// ═══════════════════════════════════════════════════════════════════════════
void _showCreateRxDialog(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreateRxSheet(ref: ref),
  );
}

class _CreateRxSheet extends StatefulWidget {
  const _CreateRxSheet({required this.ref});
  final WidgetRef ref;
  @override
  State<_CreateRxSheet> createState() => _CreateRxSheetState();
}

class _CreateRxSheetState extends State<_CreateRxSheet> {
  final _diagnosisCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  int? _selectedPatientId;
  bool _saving = false;
  final List<Map<String, TextEditingController>> _items = [];

  @override
  void initState() { super.initState(); _addItem(); }

  void _addItem() => setState(() => _items.add({
    'medication_name': TextEditingController(),
    'dosage': TextEditingController(),
    'frequency': TextEditingController(),
    'duration': TextEditingController(),
    'quantity': TextEditingController(text: '1'),
    'instructions': TextEditingController(),
  }));

  void _removeItem(int i) => setState(() { for (final c in _items[i].values) c.dispose(); _items.removeAt(i); });

  @override
  void dispose() { _diagnosisCtrl.dispose(); _notesCtrl.dispose(); for (final m in _items) for (final c in m.values) c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final patients = widget.ref.watch(_patientsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.medication_rounded, color: Color(0xFF6366F1), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('New Prescription', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 16),
              const Divider(height: 1),
            ]),
          ),

          // ── Form ──
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              children: [
                // Patient autocomplete
                Text('Patient *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(height: 6),
                patients.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Failed to load patients'),
                  data: (list) => Autocomplete<Map>(
                    optionsBuilder: (v) {
                      if (v.text.isEmpty) return list.cast<Map>();
                      final q = v.text.toLowerCase();
                      return list.cast<Map>().where((p) =>
                        '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.toLowerCase().contains(q) ||
                        '${p['phone'] ?? ''}'.contains(q));
                    },
                    displayStringForOption: (p) => '${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim(),
                    onSelected: (p) => setState(() => _selectedPatientId = p['id']),
                    fieldViewBuilder: (ctx, ctrl, fn, onSubmit) => TextField(
                      controller: ctrl, focusNode: fn,
                      decoration: InputDecoration(
                        hintText: 'Search patients...',
                        prefixIcon: const Icon(Icons.person_search_rounded, size: 20),
                        isDense: true, filled: true,
                        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    optionsViewBuilder: (ctx, onSel, opts) => Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4, borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 360),
                          child: ListView.builder(
                            padding: EdgeInsets.zero, shrinkWrap: true,
                            itemCount: opts.length,
                            itemBuilder: (_, i) {
                              final p = opts.elementAt(i);
                              return ListTile(
                                dense: true,
                                title: Text('${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'),
                                subtitle: Text(p['phone'] ?? '', style: const TextStyle(fontSize: 12)),
                                onTap: () => onSel(p),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildField('Diagnosis', _diagnosisCtrl, hint: 'e.g. Upper respiratory infection'),
                const SizedBox(height: 16),
                _buildField('Notes', _notesCtrl, hint: 'Additional notes...', maxLines: 3),

                // ── Medication items ──
                const SizedBox(height: 24),
                Row(children: [
                  const Icon(Icons.medication_liquid_rounded, size: 18, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Medications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add', style: TextStyle(fontSize: 13))),
                ]),
                const SizedBox(height: 8),
                ..._items.asMap().entries.map((e) => _ItemFormCard(
                  index: e.key, ctrls: e.value,
                  onRemove: _items.length > 1 ? () => _removeItem(e.key) : null,
                )),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_saving ? 'Creating...' : 'Create Prescription'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {String? hint, int maxLines = 1}) {
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
    if (_selectedPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a patient'), behavior: SnackBarBehavior.floating));
      return;
    }
    if (_items.any((m) => m['medication_name']!.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All medications need a name'), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = widget.ref.read(dioProvider);
      final body = {
        'patient': _selectedPatientId,
        'diagnosis': _diagnosisCtrl.text,
        'notes': _notesCtrl.text,
        'items': _items.map((m) => {
          'medication_name': m['medication_name']!.text,
          'dosage': m['dosage']!.text,
          'frequency': m['frequency']!.text,
          'duration': m['duration']!.text,
          'quantity': int.tryParse(m['quantity']!.text) ?? 1,
          'instructions': m['instructions']!.text,
        }).toList(),
      };
      await dio.post('/prescriptions/', data: body);
      widget.ref.invalidate(_rxProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Prescription created'), behavior: SnackBarBehavior.floating, backgroundColor: Color(0xFF10B981)));
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = _extractError(e);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CREATE PHARMACY RX DIALOG
// ═══════════════════════════════════════════════════════════════════════════
void _showCreatePharmRxDialog(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreatePharmRxSheet(ref: ref),
  );
}

class _CreatePharmRxSheet extends StatefulWidget {
  const _CreatePharmRxSheet({required this.ref});
  final WidgetRef ref;
  @override
  State<_CreatePharmRxSheet> createState() => _CreatePharmRxSheetState();
}

class _CreatePharmRxSheetState extends State<_CreatePharmRxSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;
  final List<Map<String, TextEditingController>> _items = [];

  @override
  void initState() { super.initState(); _addItem(); }

  void _addItem() => setState(() => _items.add({
    'medication_name': TextEditingController(),
    'dosage': TextEditingController(),
    'frequency': TextEditingController(),
    'duration': TextEditingController(),
    'quantity': TextEditingController(text: '1'),
    'instructions': TextEditingController(),
  }));

  void _removeItem(int i) => setState(() { for (final c in _items[i].values) c.dispose(); _items.removeAt(i); });

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); _notesCtrl.dispose(); for (final m in _items) for (final c in m.values) c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.local_pharmacy_rounded, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('New Walk-in Rx', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 16),
              const Divider(height: 1),
            ]),
          ),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              children: [
                _buildField('Patient Name *', _nameCtrl, hint: 'Full name'),
                const SizedBox(height: 16),
                _buildField('Phone', _phoneCtrl, hint: '+254...', keyboard: TextInputType.phone),
                const SizedBox(height: 16),
                _buildField('Notes', _notesCtrl, hint: 'Additional notes...', maxLines: 3),
                const SizedBox(height: 24),
                Row(children: [
                  const Icon(Icons.medication_liquid_rounded, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Medications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add', style: TextStyle(fontSize: 13))),
                ]),
                const SizedBox(height: 8),
                ..._items.asMap().entries.map((e) => _ItemFormCard(
                  index: e.key, ctrls: e.value,
                  onRemove: _items.length > 1 ? () => _removeItem(e.key) : null,
                )),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_saving ? 'Creating...' : 'Create Prescription'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {String? hint, int maxLines = 1, TextInputType? keyboard}) {
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
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient name is required'), behavior: SnackBarBehavior.floating));
      return;
    }
    if (_items.any((m) => m['medication_name']!.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All medications need a name'), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = widget.ref.read(dioProvider);
      final body = {
        'patient_name': _nameCtrl.text.trim(),
        'patient_phone': _phoneCtrl.text.trim(),
        'notes': _notesCtrl.text,
        'items': _items.map((m) => {
          'medication_name': m['medication_name']!.text,
          'dosage': m['dosage']!.text,
          'frequency': m['frequency']!.text,
          'duration': m['duration']!.text,
          'quantity': int.tryParse(m['quantity']!.text) ?? 1,
          'instructions': m['instructions']!.text,
        }).toList(),
      };
      await dio.post('/prescriptions/pharmacy-rx/', data: body);
      widget.ref.invalidate(_pharmProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Prescription created'), behavior: SnackBarBehavior.floating, backgroundColor: Color(0xFF10B981)));
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = _extractError(e);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  EDIT STANDARD RX DIALOG
// ═══════════════════════════════════════════════════════════════════════════
void _showEditRxDialog(BuildContext context, WidgetRef ref, dynamic rx) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditRxSheet(ref: ref, rx: rx),
  );
}

class _EditRxSheet extends StatefulWidget {
  const _EditRxSheet({required this.ref, required this.rx});
  final WidgetRef ref;
  final dynamic rx;
  @override
  State<_EditRxSheet> createState() => _EditRxSheetState();
}

class _EditRxSheetState extends State<_EditRxSheet> {
  late final TextEditingController _diagnosisCtrl;
  late final TextEditingController _notesCtrl;
  bool _saving = false;
  final List<Map<String, TextEditingController>> _items = [];

  @override
  void initState() {
    super.initState();
    _diagnosisCtrl = TextEditingController(text: widget.rx['diagnosis'] ?? '');
    _notesCtrl = TextEditingController(text: widget.rx['notes'] ?? '');
    final existingItems = (widget.rx['items'] as List?) ?? [];
    for (final it in existingItems) {
      _items.add({
        'medication_name': TextEditingController(text: it['medication_name'] ?? it['custom_medication_name'] ?? ''),
        'dosage': TextEditingController(text: it['dosage'] ?? ''),
        'frequency': TextEditingController(text: it['frequency'] ?? ''),
        'duration': TextEditingController(text: it['duration'] ?? ''),
        'quantity': TextEditingController(text: '${it['quantity'] ?? 1}'),
        'instructions': TextEditingController(text: it['instructions'] ?? ''),
      });
    }
    if (_items.isEmpty) _addItem();
  }

  void _addItem() => setState(() => _items.add({
    'medication_name': TextEditingController(),
    'dosage': TextEditingController(),
    'frequency': TextEditingController(),
    'duration': TextEditingController(),
    'quantity': TextEditingController(text: '1'),
    'instructions': TextEditingController(),
  }));

  void _removeItem(int i) => setState(() { for (final c in _items[i].values) c.dispose(); _items.removeAt(i); });

  @override
  void dispose() { _diagnosisCtrl.dispose(); _notesCtrl.dispose(); for (final m in _items) for (final c in m.values) c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.edit_rounded, color: Color(0xFFF59E0B), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('Edit Rx #${widget.rx['id']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 16),
              const Divider(height: 1),
            ]),
          ),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              children: [
                _buildField('Diagnosis', _diagnosisCtrl),
                const SizedBox(height: 16),
                _buildField('Notes', _notesCtrl, maxLines: 3),
                const SizedBox(height: 24),
                Row(children: [
                  const Icon(Icons.medication_liquid_rounded, size: 18, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Medications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add', style: TextStyle(fontSize: 13))),
                ]),
                const SizedBox(height: 8),
                ..._items.asMap().entries.map((e) => _ItemFormCard(index: e.key, ctrls: e.value, onRemove: _items.length > 1 ? () => _removeItem(e.key) : null)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_saving ? 'Saving...' : 'Save Changes'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {String? hint, int maxLines = 1}) {
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
    if (_items.any((m) => m['medication_name']!.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All medications need a name'), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = widget.ref.read(dioProvider);
      final body = {
        'diagnosis': _diagnosisCtrl.text,
        'notes': _notesCtrl.text,
        'items': _items.map((m) => {
          'medication_name': m['medication_name']!.text,
          'dosage': m['dosage']!.text,
          'frequency': m['frequency']!.text,
          'duration': m['duration']!.text,
          'quantity': int.tryParse(m['quantity']!.text) ?? 1,
          'instructions': m['instructions']!.text,
        }).toList(),
      };
      await dio.patch('/prescriptions/${widget.rx['id']}/', data: body);
      widget.ref.invalidate(_rxProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Prescription updated'), behavior: SnackBarBehavior.floating, backgroundColor: Color(0xFF10B981)));
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = _extractError(e);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  DELETE RX
// ═══════════════════════════════════════════════════════════════════════════
Future<void> _deleteRx(BuildContext context, WidgetRef ref, int id) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Prescription?'),
      content: const Text('This will permanently delete this prescription.'),
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
  if (confirmed != true || !context.mounted) return;
  try {
    final dio = ref.read(dioProvider);
    await dio.delete('/prescriptions/$id/');
    ref.invalidate(_rxProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prescription deleted'), behavior: SnackBarBehavior.floating));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete'), behavior: SnackBarBehavior.floating, backgroundColor: Colors.red));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHARED: MEDICATION ITEM FORM CARD
// ═══════════════════════════════════════════════════════════════════════════
class _ItemFormCard extends StatelessWidget {
  const _ItemFormCard({required this.index, required this.ctrls, this.onRemove});
  final int index;
  final Map<String, TextEditingController> ctrls;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Center(child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)))),
          ),
          const SizedBox(width: 8),
          Text('Medication ${index + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (onRemove != null) IconButton(icon: const Icon(Icons.remove_circle_rounded, color: Colors.red, size: 20), onPressed: onRemove, visualDensity: VisualDensity.compact),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: ctrls['medication_name'],
          decoration: InputDecoration(labelText: 'Medication Name *', isDense: true, filled: true, fillColor: cs.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(
            controller: ctrls['dosage'],
            decoration: InputDecoration(labelText: 'Dosage', isDense: true, filled: true, fillColor: cs.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
            style: const TextStyle(fontSize: 14),
          )),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: ctrls['frequency'],
            decoration: InputDecoration(labelText: 'Frequency', isDense: true, filled: true, fillColor: cs.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
            style: const TextStyle(fontSize: 14),
          )),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(
            controller: ctrls['duration'],
            decoration: InputDecoration(labelText: 'Duration', isDense: true, filled: true, fillColor: cs.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
            style: const TextStyle(fontSize: 14),
          )),
          const SizedBox(width: 10),
          SizedBox(width: 80, child: TextField(
            controller: ctrls['quantity'],
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: 'Qty', isDense: true, filled: true, fillColor: cs.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
            style: const TextStyle(fontSize: 14),
          )),
        ]),
        const SizedBox(height: 10),
        TextField(
          controller: ctrls['instructions'],
          maxLines: 2,
          decoration: InputDecoration(labelText: 'Instructions', isDense: true, filled: true, fillColor: cs.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
          style: const TextStyle(fontSize: 14),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHARED: MEDICATION DISPLAY CARD
// ═══════════════════════════════════════════════════════════════════════════
class _MedicationCard extends StatelessWidget {
  const _MedicationCard({required this.index, required this.item, this.showQuantity = false, this.showRefills = false, this.showInstructions = false});
  final int index;
  final dynamic item;
  final bool showQuantity;
  final bool showRefills;
  final bool showInstructions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Center(child: Text('$index', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(
            item['medication_name'] ?? item['custom_medication_name'] ?? 'Unnamed',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          )),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 16, runSpacing: 6, children: [
          if ((item['dosage'] ?? item['dose'] ?? '').toString().isNotEmpty)
            _MedProp(icon: Icons.scale_rounded, label: 'Dosage',
              value: '${item['dosage'] ?? item['dose']}${(item['dose_unit'] ?? '').toString().isNotEmpty ? ' ${item['dose_unit']}' : ''}'),
          if ((item['frequency'] ?? '').toString().isNotEmpty)
            _MedProp(icon: Icons.repeat_rounded, label: 'Frequency', value: item['frequency']),
          if ((item['duration'] ?? item['duration_days'] ?? '').toString().isNotEmpty)
            _MedProp(icon: Icons.timer_rounded, label: 'Duration',
              value: '${item['duration'] ?? '${item['duration_days']} days'}'),
          if (showQuantity && item['quantity'] != null)
            _MedProp(icon: Icons.inventory_2_rounded, label: 'Qty', value: '${item['quantity']}'),
          if (showRefills && (item['refills'] ?? 0) > 0)
            _MedProp(icon: Icons.refresh_rounded, label: 'Refills', value: '${item['refills']}'),
        ]),
        if (showInstructions && (item['instructions'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 14, color: cs.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(item['instructions'], style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _MedProp extends StatelessWidget {
  const _MedProp({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: cs.onSurfaceVariant),
      const SizedBox(width: 4),
      Text('$label: ', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHARED: INFO TILE
// ═══════════════════════════════════════════════════════════════════════════
class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: cs.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ERROR EXTRACTION HELPER
// ═══════════════════════════════════════════════════════════════════════════
String _extractError(DioException e) {
  final d = e.response?.data;
  if (d is Map) {
    final parts = <String>[];
    for (final entry in d.entries) {
      final val = entry.value;
      if (val is List) {
        parts.add('${entry.key}: ${val.join(', ')}');
      } else {
        parts.add('${entry.key}: $val');
      }
    }
    if (parts.isNotEmpty) return parts.join('\n');
  }
  if (d is String && d.isNotEmpty) return d;
  return e.message ?? 'Request failed';
}
