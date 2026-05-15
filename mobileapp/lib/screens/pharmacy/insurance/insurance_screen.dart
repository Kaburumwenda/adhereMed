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

// ── Claims ──
final _claimSearchProvider = StateProvider<String>((ref) => '');
final _claimStatusProvider = StateProvider<String>((ref) => '');
final _claimProviderFilter = StateProvider<int?>((ref) => null);

final _claimsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final params = <String, dynamic>{'page_size': 200, 'ordering': '-created_at'};
  final status = ref.watch(_claimStatusProvider);
  if (status.isNotEmpty) params['status'] = status;
  final provId = ref.watch(_claimProviderFilter);
  if (provId != null) params['provider'] = provId;
  final res = await dio.get('/insurance/claims/', queryParameters: params);
  final items = (res.data['results'] as List?) ?? (res.data is List ? res.data as List : []);
  final q = ref.watch(_claimSearchProvider).toLowerCase();
  if (q.isEmpty) return items;
  return items.where((c) =>
    '${c['reference'] ?? ''}'.toLowerCase().contains(q) ||
    '${c['member_name'] ?? ''}'.toLowerCase().contains(q) ||
    '${c['member_number'] ?? ''}'.toLowerCase().contains(q) ||
    '${c['provider_name'] ?? ''}'.toLowerCase().contains(q) ||
    '${c['invoice_number'] ?? ''}'.toLowerCase().contains(q)
  ).toList();
});

// ── Stats ──
final _statsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/insurance/claims/stats/');
  return res.data as Map<String, dynamic>;
});

// ── Providers (insurance companies) ──
final _provSearchProvider = StateProvider<String>((ref) => '');
final _insuranceProvidersProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/insurance/providers/', queryParameters: {'page_size': 500});
  final items = (res.data['results'] as List?) ?? (res.data is List ? res.data as List : []);
  final q = ref.watch(_provSearchProvider).toLowerCase();
  if (q.isEmpty) return items;
  return items.where((p) =>
    '${p['name'] ?? ''}'.toLowerCase().contains(q) ||
    '${p['code'] ?? ''}'.toLowerCase().contains(q) ||
    '${p['contact_person'] ?? ''}'.toLowerCase().contains(q)
  ).toList();
});

// ═══════════════════════════════════════════════════════════════════════════
//  STATUS HELPERS
// ═══════════════════════════════════════════════════════════════════════════
const _claimStatuses = ['draft', 'submitted', 'under_review', 'approved', 'partially_approved', 'rejected', 'paid'];
const _claimStatusLabels = {
  'draft': 'Draft', 'submitted': 'Submitted', 'under_review': 'Under Review',
  'approved': 'Approved', 'partially_approved': 'Partial', 'rejected': 'Rejected', 'paid': 'Paid',
};

Color _statusColor(String s) => switch (s) {
  'draft' => const Color(0xFF94A3B8),
  'submitted' => const Color(0xFF3B82F6),
  'under_review' => const Color(0xFFF59E0B),
  'approved' => const Color(0xFF10B981),
  'partially_approved' => const Color(0xFF14B8A6),
  'rejected' => const Color(0xFFEF4444),
  'paid' => const Color(0xFF059669),
  _ => const Color(0xFF94A3B8),
};

IconData _statusIcon(String s) => switch (s) {
  'draft' => Icons.edit_note_rounded,
  'submitted' => Icons.send_rounded,
  'under_review' => Icons.hourglass_top_rounded,
  'approved' => Icons.check_circle_rounded,
  'partially_approved' => Icons.check_circle_outline_rounded,
  'rejected' => Icons.cancel_rounded,
  'paid' => Icons.payments_rounded,
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

String _fmtMoney(dynamic v) {
  if (v == null) return '0.00';
  final n = double.tryParse(v.toString()) ?? 0;
  return NumberFormat('#,##0.00').format(n);
}

// ═══════════════════════════════════════════════════════════════════════════
//  MAIN SCREEN — TABBED (Claims + Providers)
// ═══════════════════════════════════════════════════════════════════════════
class InsuranceScreen extends ConsumerStatefulWidget {
  const InsuranceScreen({super.key});
  @override
  ConsumerState<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends ConsumerState<InsuranceScreen> with TickerProviderStateMixin {
  late final TabController _tabCtrl;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
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
        title: const Text('Insurance', style: TextStyle(fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: 'Claims'),
            Tab(text: 'Providers'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_currentTab == 0) {
            _showCreateClaimDialog(context, ref);
          } else {
            _showProviderDialog(context, ref);
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(_currentTab == 0 ? 'New Claim' : 'New Provider'),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _ClaimsTab(),
          _ProvidersTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TAB 1: CLAIMS
// ═══════════════════════════════════════════════════════════════════════════
class _ClaimsTab extends ConsumerStatefulWidget {
  const _ClaimsTab();
  @override
  ConsumerState<_ClaimsTab> createState() => _ClaimsTabState();
}

class _ClaimsTabState extends ConsumerState<_ClaimsTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Timer? _debounce;

  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final data = ref.watch(_claimsProvider);
    final stats = ref.watch(_statsProvider);
    final statusFilter = ref.watch(_claimStatusProvider);

    return Column(
      children: [
        // ── Stats KPIs ──
        stats.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (s) {
            final totals = s['totals'] as Map? ?? {};
            return _KpiRow(items: [
              _Kpi('Claims', (totals['count'] ?? 0) as int, const Color(0xFF6366F1)),
              _Kpi('Approved', 0, const Color(0xFF10B981), money: _fmtMoney(totals['approved'])),
              _Kpi('Paid', 0, const Color(0xFF059669), money: _fmtMoney(totals['paid'])),
              _Kpi('Outstanding', 0, const Color(0xFFF59E0B), money: _fmtMoney(totals['outstanding'])),
            ]);
          },
        ),

        // ── Search + Filter ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search claims...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true, filled: true,
                    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 300), () => ref.read(_claimSearchProvider.notifier).state = v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: Badge(
                  isLabelVisible: statusFilter.isNotEmpty,
                  child: Icon(Icons.filter_list_rounded, color: statusFilter.isNotEmpty ? cs.primary : null),
                ),
                onSelected: (v) => ref.read(_claimStatusProvider.notifier).state = v,
                itemBuilder: (_) => [
                  const PopupMenuItem(value: '', child: Text('All Statuses')),
                  ..._claimStatuses.map((s) => PopupMenuItem(
                    value: s,
                    child: Row(children: [
                      Icon(_statusIcon(s), size: 16, color: _statusColor(s)),
                      const SizedBox(width: 8),
                      Text(_claimStatusLabels[s] ?? s),
                    ]),
                  )),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1),

        // ── Claims list ──
        Expanded(
          child: data.when(
            loading: () => const LoadingShimmer(),
            error: (e, _) => ErrorRetry(message: 'Failed to load claims', onRetry: () => ref.invalidate(_claimsProvider)),
            data: (items) {
              if (items.isEmpty) return const EmptyState(icon: Icons.description_rounded, title: 'No claims found');
              return RefreshIndicator(
                onRefresh: () async { ref.invalidate(_claimsProvider); ref.invalidate(_statsProvider); },
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _ClaimCard(claim: items[i], ref: ref)
                    .animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: (40 * i).clamp(0, 400))).slideY(begin: 0.05, end: 0),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Claim Card ──
class _ClaimCard extends StatelessWidget {
  const _ClaimCard({required this.claim, required this.ref});
  final dynamic claim;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = claim['status'] ?? 'draft';
    final sc = _statusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showClaimDetail(context, claim, ref),
        onLongPress: () => _showClaimActions(context, claim, ref),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 5, height: 110,
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
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Icon(_statusIcon(status), color: sc, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(claim['reference'] ?? '#${claim['id']}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            Text(claim['member_name'] ?? 'N/A',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          ]),
                        ),
                        _StatusChip(label: _claimStatusLabels[status] ?? status, color: sc),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Icon(Icons.business_rounded, size: 13, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(child: Text(claim['provider_name'] ?? 'N/A',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        _MoneyLabel(label: 'Claimed', amount: claim['claim_amount'], color: const Color(0xFF3B82F6)),
                        const SizedBox(width: 16),
                        _MoneyLabel(label: 'Approved', amount: claim['approved_amount'], color: const Color(0xFF10B981)),
                        const Spacer(),
                        Text(_fmtDate(claim['created_at']?.toString()),
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      ]),
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
//  TAB 2: PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════
class _ProvidersTab extends ConsumerStatefulWidget {
  const _ProvidersTab();
  @override
  ConsumerState<_ProvidersTab> createState() => _ProvidersTabState();
}

class _ProvidersTabState extends ConsumerState<_ProvidersTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  Timer? _debounce;

  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final data = ref.watch(_insuranceProvidersProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search providers...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true, filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: const TextStyle(fontSize: 14),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () => ref.read(_provSearchProvider.notifier).state = v);
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: data.when(
            loading: () => const LoadingShimmer(),
            error: (e, _) => ErrorRetry(message: 'Failed to load', onRetry: () => ref.invalidate(_insuranceProvidersProvider)),
            data: (items) {
              if (items.isEmpty) return const EmptyState(icon: Icons.shield_rounded, title: 'No providers');
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(_insuranceProvidersProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _ProviderCard(provider: items[i], ref: ref)
                    .animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: (40 * i).clamp(0, 400))).slideY(begin: 0.05, end: 0),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Provider Card ──
class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.provider, required this.ref});
  final dynamic provider;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = provider['is_active'] == true;
    final sc = active ? const Color(0xFF10B981) : const Color(0xFF94A3B8);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showProviderDetail(context, provider, ref),
        onLongPress: () => _showProviderActions(context, provider, ref),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.shield_rounded, color: sc, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(provider['name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      if ((provider['code'] ?? '').toString().isNotEmpty)
                        Text('Code: ${provider['code']}',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ]),
                  ),
                  _StatusChip(label: active ? 'Active' : 'Inactive', color: sc),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  if ((provider['contact_person'] ?? '').toString().isNotEmpty) ...[
                    Icon(Icons.person_rounded, size: 13, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(provider['contact_person'],
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 16),
                  ],
                  if ((provider['phone'] ?? '').toString().isNotEmpty) ...[
                    Icon(Icons.phone_rounded, size: 13, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(provider['phone'],
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _MoneyLabel(label: 'Open Claims', amount: provider['open_claims'], color: const Color(0xFFF59E0B), isCount: true),
                  const SizedBox(width: 20),
                  _MoneyLabel(label: 'Outstanding', amount: provider['total_outstanding'], color: const Color(0xFFEF4444)),
                ]),
              ],
            ),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(label.toUpperCase(),
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
  );
}

class _MoneyLabel extends StatelessWidget {
  const _MoneyLabel({required this.label, required this.amount, required this.color, this.isCount = false});
  final String label;
  final dynamic amount;
  final Color color;
  final bool isCount;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text('$label: ', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    Text(isCount ? '${amount ?? 0}' : _fmtMoney(amount),
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
  ]);
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.items});
  final List<_Kpi> items;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: items.map((k) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: k.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: k.color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text(k.money ?? '${k.value}',
              style: TextStyle(fontSize: k.money != null ? 14 : 20, fontWeight: FontWeight.w800, color: k.color)),
            const SizedBox(height: 2),
            Text(k.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: k.color.withValues(alpha: 0.8)),
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      )).toList(),
    ),
  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
}

class _Kpi {
  const _Kpi(this.label, this.value, this.color, {this.money});
  final String label;
  final int value;
  final Color color;
  final String? money;
}

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
//  CLAIM DETAIL
// ═══════════════════════════════════════════════════════════════════════════
void _showClaimDetail(BuildContext context, dynamic claim, WidgetRef ref) {
  final cs = Theme.of(context).colorScheme;
  final status = claim['status'] ?? 'draft';
  final sc = _statusColor(status);
  final items = (claim['items'] as List?) ?? [];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: ListView(
          controller: scrollCtrl,
          padding: EdgeInsets.zero,
          children: [
            // ── Hero ──
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [sc.withValues(alpha: 0.15), sc.withValues(alpha: 0.03)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(_statusIcon(status), size: 32, color: sc)),
                const SizedBox(height: 12),
                Text(claim['reference'] ?? 'Claim #${claim['id']}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cs.onSurface)),
                const SizedBox(height: 6),
                _StatusChip(label: _claimStatusLabels[status] ?? status, color: sc),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _InfoTile(icon: Icons.person_rounded, label: 'Member', value: '${claim['member_name'] ?? 'N/A'} (${claim['member_number'] ?? ''})'),
                _InfoTile(icon: Icons.business_rounded, label: 'Provider', value: claim['provider_name'] ?? 'N/A'),
                if ((claim['scheme_name'] ?? '').toString().isNotEmpty)
                  _InfoTile(icon: Icons.account_balance_rounded, label: 'Scheme', value: claim['scheme_name']),
                if ((claim['invoice_number'] ?? '').toString().isNotEmpty)
                  _InfoTile(icon: Icons.receipt_rounded, label: 'Invoice', value: claim['invoice_number']),
                if ((claim['diagnosis'] ?? '').toString().isNotEmpty)
                  _InfoTile(icon: Icons.medical_information_rounded, label: 'Diagnosis', value: claim['diagnosis']),
                _InfoTile(icon: Icons.calendar_today_rounded, label: 'Created', value: _fmtDateTime(claim['created_at']?.toString())),
                if (claim['submitted_at'] != null)
                  _InfoTile(icon: Icons.send_rounded, label: 'Submitted', value: _fmtDateTime(claim['submitted_at']?.toString())),

                // ── Financial summary ──
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: _FinancialTile(label: 'Claimed', value: _fmtMoney(claim['claim_amount']), color: const Color(0xFF3B82F6))),
                      Expanded(child: _FinancialTile(label: 'Approved', value: _fmtMoney(claim['approved_amount']), color: const Color(0xFF10B981))),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _FinancialTile(label: 'Paid', value: _fmtMoney(claim['paid_amount']), color: const Color(0xFF059669))),
                      Expanded(child: _FinancialTile(label: 'Outstanding', value: _fmtMoney(claim['outstanding']), color: const Color(0xFFF59E0B))),
                    ]),
                  ]),
                ),

                // ── Rejection reason ──
                if ((claim['rejection_reason'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(claim['rejection_reason'], style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B)))),
                    ]),
                  ),
                ],

                // ── Notes ──
                if ((claim['notes'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD43B).withValues(alpha: 0.3))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.note_rounded, size: 16, color: Color(0xFF92400E)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(claim['notes'], style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)))),
                    ]),
                  ),
                ],

                // ── Line items ──
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Line Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
                  const SizedBox(height: 10),
                  ...items.asMap().entries.map((e) {
                    final it = e.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        Container(
                          width: 26, height: 26,
                          decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Center(child: Text('${e.key + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(it['description'] ?? 'Item', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('${it['quantity'] ?? 1} × ${_fmtMoney(it['unit_price'])}',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ])),
                        Text(_fmtMoney(it['total']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ]),
                    );
                  }),
                ],

                // ── Actions ──
                const SizedBox(height: 20),
                ..._buildClaimActions(ctx, claim, ref, status),
              ]),
            ),
          ],
        ),
      ),
    ),
  );
}

List<Widget> _buildClaimActions(BuildContext context, dynamic claim, WidgetRef ref, String status) {
  final actions = <Widget>[];
  final id = claim['id'];

  if (status == 'draft') {
    actions.add(Row(children: [
      Expanded(child: FilledButton.icon(
        onPressed: () => _submitClaim(context, ref, id),
        icon: const Icon(Icons.send_rounded, size: 18),
        label: const Text('Submit Claim'),
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      )),
      const SizedBox(width: 12),
      Expanded(child: OutlinedButton.icon(
        onPressed: () { Navigator.pop(context); _showEditClaimDialog(context, ref, claim); },
        icon: const Icon(Icons.edit_rounded, size: 18),
        label: const Text('Edit'),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      )),
    ]));
  }

  if (status == 'submitted' || status == 'under_review') {
    actions.add(Row(children: [
      Expanded(child: FilledButton.icon(
        onPressed: () => _showApproveDialog(context, ref, claim),
        icon: const Icon(Icons.check_circle_rounded, size: 18),
        label: const Text('Approve'),
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      )),
      const SizedBox(width: 12),
      Expanded(child: OutlinedButton.icon(
        onPressed: () => _showRejectDialog(context, ref, id),
        icon: const Icon(Icons.cancel_rounded, size: 18),
        label: const Text('Reject'),
        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444),
          side: const BorderSide(color: Color(0xFFEF4444)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      )),
    ]));
  }

  if (status == 'approved' || status == 'partially_approved') {
    actions.add(Row(children: [
      Expanded(child: FilledButton.icon(
        onPressed: () => _showPaymentDialog(context, ref, id),
        icon: const Icon(Icons.payments_rounded, size: 18),
        label: const Text('Record Payment'),
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      )),
      const SizedBox(width: 12),
      Expanded(child: OutlinedButton.icon(
        onPressed: () => _showRejectDialog(context, ref, id),
        icon: const Icon(Icons.cancel_rounded, size: 18),
        label: const Text('Reject'),
        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444),
          side: const BorderSide(color: Color(0xFFEF4444)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      )),
    ]));
  }

  return actions;
}

class _FinancialTile extends StatelessWidget {
  const _FinancialTile({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════
//  CLAIM ACTIONS — long press
// ═══════════════════════════════════════════════════════════════════════════
void _showClaimActions(BuildContext context, dynamic claim, WidgetRef ref) {
  final status = claim['status'] ?? 'draft';
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          ListTile(leading: const Icon(Icons.visibility_rounded, color: Color(0xFF3B82F6)),
            title: const Text('View Details'),
            onTap: () { Navigator.pop(ctx); _showClaimDetail(context, claim, ref); }),
          if (status == 'draft') ...[
            ListTile(leading: const Icon(Icons.edit_rounded, color: Color(0xFFF59E0B)),
              title: const Text('Edit'),
              onTap: () { Navigator.pop(ctx); _showEditClaimDialog(context, ref, claim); }),
            ListTile(leading: const Icon(Icons.send_rounded, color: Color(0xFF3B82F6)),
              title: const Text('Submit'),
              onTap: () { Navigator.pop(ctx); _submitClaim(context, ref, claim['id']); }),
          ],
          if (status == 'submitted' || status == 'under_review') ...[
            ListTile(leading: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
              title: const Text('Approve'),
              onTap: () { Navigator.pop(ctx); _showApproveDialog(context, ref, claim); }),
            ListTile(leading: const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444)),
              title: const Text('Reject'),
              onTap: () { Navigator.pop(ctx); _showRejectDialog(context, ref, claim['id']); }),
          ],
          if (status == 'approved' || status == 'partially_approved')
            ListTile(leading: const Icon(Icons.payments_rounded, color: Color(0xFF059669)),
              title: const Text('Record Payment'),
              onTap: () { Navigator.pop(ctx); _showPaymentDialog(context, ref, claim['id']); }),
          ListTile(leading: const Icon(Icons.delete_rounded, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () { Navigator.pop(ctx); _deleteClaim(context, ref, claim['id']); }),
        ]),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  CLAIM STATUS ACTIONS
// ═══════════════════════════════════════════════════════════════════════════
Future<void> _submitClaim(BuildContext context, WidgetRef ref, int id) async {
  final ok = await _confirm(context, 'Submit Claim?', 'This will submit the claim for review.');
  if (!ok || !context.mounted) return;
  try {
    await ref.read(dioProvider).post('/insurance/claims/$id/submit/');
    ref.invalidate(_claimsProvider); ref.invalidate(_statsProvider);
    if (context.mounted) {
      Navigator.pop(context);
      _snack(context, 'Claim submitted', const Color(0xFF3B82F6));
    }
  } on DioException catch (e) { if (context.mounted) _snackErr(context, e); }
}

void _showApproveDialog(BuildContext context, WidgetRef ref, dynamic claim) {
  final ctrl = TextEditingController(text: claim['claim_amount']?.toString() ?? '');
  showDialog(context: context, builder: (ctx) => AlertDialog(
    title: const Text('Approve Claim'),
    content: TextField(
      controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: 'Approved Amount', prefixText: 'KSH '),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      FilledButton(
        onPressed: () async {
          Navigator.pop(ctx);
          try {
            await ref.read(dioProvider).post('/insurance/claims/${claim['id']}/approve/', data: {
              'approved_amount': double.tryParse(ctrl.text) ?? 0,
            });
            ref.invalidate(_claimsProvider); ref.invalidate(_statsProvider);
            if (context.mounted) { Navigator.pop(context); _snack(context, 'Claim approved', const Color(0xFF10B981)); }
          } on DioException catch (e) { if (context.mounted) _snackErr(context, e); }
        },
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
        child: const Text('Approve'),
      ),
    ],
  ));
}

void _showRejectDialog(BuildContext context, WidgetRef ref, int id) {
  final ctrl = TextEditingController();
  showDialog(context: context, builder: (ctx) => AlertDialog(
    title: const Text('Reject Claim'),
    content: TextField(controller: ctrl, maxLines: 3,
      decoration: const InputDecoration(labelText: 'Reason for rejection')),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      FilledButton(
        onPressed: () async {
          Navigator.pop(ctx);
          try {
            await ref.read(dioProvider).post('/insurance/claims/$id/reject/', data: {'reason': ctrl.text});
            ref.invalidate(_claimsProvider); ref.invalidate(_statsProvider);
            if (context.mounted) { Navigator.pop(context); _snack(context, 'Claim rejected', const Color(0xFFEF4444)); }
          } on DioException catch (e) { if (context.mounted) _snackErr(context, e); }
        },
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
        child: const Text('Reject'),
      ),
    ],
  ));
}

void _showPaymentDialog(BuildContext context, WidgetRef ref, int id) {
  final amountCtrl = TextEditingController();
  final refCtrl = TextEditingController();
  showDialog(context: context, builder: (ctx) => AlertDialog(
    title: const Text('Record Payment'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Amount', prefixText: 'KSH ')),
      const SizedBox(height: 12),
      TextField(controller: refCtrl,
        decoration: const InputDecoration(labelText: 'Payment Reference')),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      FilledButton(
        onPressed: () async {
          Navigator.pop(ctx);
          try {
            await ref.read(dioProvider).post('/insurance/claims/$id/record-payment/', data: {
              'amount': double.tryParse(amountCtrl.text) ?? 0,
              'reference': refCtrl.text,
            });
            ref.invalidate(_claimsProvider); ref.invalidate(_statsProvider);
            if (context.mounted) { Navigator.pop(context); _snack(context, 'Payment recorded', const Color(0xFF059669)); }
          } on DioException catch (e) { if (context.mounted) _snackErr(context, e); }
        },
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
        child: const Text('Record'),
      ),
    ],
  ));
}

Future<void> _deleteClaim(BuildContext context, WidgetRef ref, int id) async {
  final ok = await _confirm(context, 'Delete Claim?', 'This will permanently delete this claim.');
  if (!ok || !context.mounted) return;
  try {
    await ref.read(dioProvider).delete('/insurance/claims/$id/');
    ref.invalidate(_claimsProvider); ref.invalidate(_statsProvider);
    if (context.mounted) _snack(context, 'Claim deleted', Colors.grey);
  } catch (_) { if (context.mounted) _snack(context, 'Failed to delete', Colors.red); }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CREATE / EDIT CLAIM
// ═══════════════════════════════════════════════════════════════════════════
void _showCreateClaimDialog(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _ClaimFormSheet(ref: ref));
}

void _showEditClaimDialog(BuildContext context, WidgetRef ref, dynamic claim) {
  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _ClaimFormSheet(ref: ref, claim: claim));
}

class _ClaimFormSheet extends StatefulWidget {
  const _ClaimFormSheet({required this.ref, this.claim});
  final WidgetRef ref;
  final dynamic claim;
  @override
  State<_ClaimFormSheet> createState() => _ClaimFormSheetState();
}

class _ClaimFormSheetState extends State<_ClaimFormSheet> {
  late final TextEditingController _memberNameCtrl;
  late final TextEditingController _memberNumCtrl;
  late final TextEditingController _schemeCtrl;
  late final TextEditingController _invoiceCtrl;
  late final TextEditingController _diagnosisCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _amountCtrl;
  int? _selectedProviderId;
  bool _saving = false;
  final List<Map<String, TextEditingController>> _items = [];

  bool get _isEdit => widget.claim != null;

  @override
  void initState() {
    super.initState();
    final c = widget.claim;
    _memberNameCtrl = TextEditingController(text: c?['member_name'] ?? '');
    _memberNumCtrl = TextEditingController(text: c?['member_number'] ?? '');
    _schemeCtrl = TextEditingController(text: c?['scheme_name'] ?? '');
    _invoiceCtrl = TextEditingController(text: c?['invoice_number'] ?? '');
    _diagnosisCtrl = TextEditingController(text: c?['diagnosis'] ?? '');
    _notesCtrl = TextEditingController(text: c?['notes'] ?? '');
    _amountCtrl = TextEditingController(text: c?['claim_amount']?.toString() ?? '');
    _selectedProviderId = c?['provider'];

    final existing = (c?['items'] as List?) ?? [];
    for (final it in existing) {
      _items.add({
        'description': TextEditingController(text: it['description'] ?? ''),
        'quantity': TextEditingController(text: '${it['quantity'] ?? 1}'),
        'unit_price': TextEditingController(text: '${it['unit_price'] ?? ''}'),
      });
    }
    if (_items.isEmpty) _addItem();
  }

  void _addItem() => setState(() => _items.add({
    'description': TextEditingController(),
    'quantity': TextEditingController(text: '1'),
    'unit_price': TextEditingController(),
  }));

  void _removeItem(int i) => setState(() { for (final c in _items[i].values) c.dispose(); _items.removeAt(i); });

  void _recalcTotal() {
    double total = 0;
    for (final m in _items) {
      final qty = int.tryParse(m['quantity']!.text) ?? 0;
      final price = double.tryParse(m['unit_price']!.text) ?? 0;
      total += qty * price;
    }
    _amountCtrl.text = total.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _memberNameCtrl.dispose(); _memberNumCtrl.dispose(); _schemeCtrl.dispose();
    _invoiceCtrl.dispose(); _diagnosisCtrl.dispose(); _notesCtrl.dispose(); _amountCtrl.dispose();
    for (final m in _items) for (final c in m.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final providers = widget.ref.watch(_insuranceProvidersProvider);
    final accent = _isEdit ? const Color(0xFFF59E0B) : const Color(0xFF6366F1);

    return DraggableScrollableSheet(
      initialChildSize: 0.92, maxChildSize: 0.95, minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(_isEdit ? Icons.edit_rounded : Icons.description_rounded, color: accent, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Text(_isEdit ? 'Edit Claim' : 'New Claim', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
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
                // Provider dropdown
                Text('Insurance Provider *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(height: 6),
                providers.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Failed to load providers'),
                  data: (list) => DropdownButtonFormField<int>(
                    value: _selectedProviderId,
                    isExpanded: true,
                    decoration: InputDecoration(isDense: true, filled: true,
                      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    hint: const Text('Select provider'),
                    items: list.map<DropdownMenuItem<int>>((p) => DropdownMenuItem(
                      value: p['id'] as int,
                      child: Text(p['name'] ?? '', style: const TextStyle(fontSize: 14)),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedProviderId = v),
                  ),
                ),
                const SizedBox(height: 16),

                Row(children: [
                  Expanded(child: _buildField('Member Name *', _memberNameCtrl, hint: 'Full name')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField('Member Number *', _memberNumCtrl, hint: 'e.g. INS-12345')),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _buildField('Scheme', _schemeCtrl, hint: 'e.g. Corporate')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField('Invoice #', _invoiceCtrl, hint: 'INV-...')),
                ]),
                const SizedBox(height: 16),
                _buildField('Diagnosis', _diagnosisCtrl, hint: 'Clinical diagnosis...', maxLines: 2),
                const SizedBox(height: 16),
                _buildField('Notes', _notesCtrl, hint: 'Additional notes...', maxLines: 2),

                // ── Line items ──
                const SizedBox(height: 24),
                Row(children: [
                  const Icon(Icons.list_alt_rounded, size: 18, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Line Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add', style: TextStyle(fontSize: 13))),
                ]),
                const SizedBox(height: 8),
                ..._items.asMap().entries.map((e) => _ClaimItemCard(
                  index: e.key, ctrls: e.value,
                  onRemove: _items.length > 1 ? () => _removeItem(e.key) : null,
                  onChanged: _recalcTotal,
                )),

                const SizedBox(height: 16),
                _buildField('Claim Amount', _amountCtrl, hint: '0.00', keyboard: const TextInputType.numberWithOptions(decimal: true)),

                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
                  label: Text(_saving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create Claim')),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
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
    if (_selectedProviderId == null) { _snack(context, 'Select a provider', Colors.orange); return; }
    if (_memberNameCtrl.text.trim().isEmpty) { _snack(context, 'Member name is required', Colors.orange); return; }
    if (_memberNumCtrl.text.trim().isEmpty) { _snack(context, 'Member number is required', Colors.orange); return; }
    setState(() => _saving = true);
    try {
      final dio = widget.ref.read(dioProvider);
      final body = {
        'provider': _selectedProviderId,
        'member_name': _memberNameCtrl.text.trim(),
        'member_number': _memberNumCtrl.text.trim(),
        'scheme_name': _schemeCtrl.text,
        'invoice_number': _invoiceCtrl.text,
        'diagnosis': _diagnosisCtrl.text,
        'notes': _notesCtrl.text,
        'claim_amount': double.tryParse(_amountCtrl.text) ?? 0,
        'items': _items.map((m) {
          final qty = int.tryParse(m['quantity']!.text) ?? 1;
          final price = double.tryParse(m['unit_price']!.text) ?? 0;
          return {
            'description': m['description']!.text,
            'quantity': qty,
            'unit_price': price,
            'total': qty * price,
          };
        }).toList(),
      };
      if (_isEdit) {
        await dio.patch('/insurance/claims/${widget.claim['id']}/', data: body);
      } else {
        await dio.post('/insurance/claims/', data: body);
      }
      widget.ref.invalidate(_claimsProvider);
      widget.ref.invalidate(_statsProvider);
      if (mounted) {
        Navigator.pop(context);
        _snack(context, _isEdit ? 'Claim updated' : 'Claim created', const Color(0xFF10B981));
      }
    } on DioException catch (e) {
      if (mounted) _snackErr(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Claim line item form card ──
class _ClaimItemCard extends StatelessWidget {
  const _ClaimItemCard({required this.index, required this.ctrls, this.onRemove, this.onChanged});
  final int index;
  final Map<String, TextEditingController> ctrls;
  final VoidCallback? onRemove;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 24, height: 24,
            decoration: BoxDecoration(color: const Color(0xFF6366F1).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Center(child: Text('${index + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6366F1))))),
          const SizedBox(width: 8),
          Text('Item ${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (onRemove != null) IconButton(icon: const Icon(Icons.remove_circle_rounded, color: Colors.red, size: 20), onPressed: onRemove, visualDensity: VisualDensity.compact),
        ]),
        const SizedBox(height: 8),
        TextField(controller: ctrls['description'],
          decoration: InputDecoration(labelText: 'Description *', isDense: true, filled: true, fillColor: cs.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
          style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        Row(children: [
          SizedBox(width: 70, child: TextField(
            controller: ctrls['quantity'],
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => onChanged?.call(),
            decoration: InputDecoration(labelText: 'Qty', isDense: true, filled: true, fillColor: cs.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
            style: const TextStyle(fontSize: 14),
          )),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: ctrls['unit_price'],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged?.call(),
            decoration: InputDecoration(labelText: 'Unit Price', isDense: true, filled: true, fillColor: cs.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
            style: const TextStyle(fontSize: 14),
          )),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Builder(builder: (_) {
              final qty = int.tryParse(ctrls['quantity']!.text) ?? 0;
              final price = double.tryParse(ctrls['unit_price']!.text) ?? 0;
              return Text(_fmtMoney(qty * price), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13));
            }),
          ),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PROVIDER DETAIL
// ═══════════════════════════════════════════════════════════════════════════
void _showProviderDetail(BuildContext context, dynamic prov, WidgetRef ref) {
  final cs = Theme.of(context).colorScheme;
  final active = prov['is_active'] == true;
  final sc = active ? const Color(0xFF10B981) : const Color(0xFF94A3B8);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: ListView(
          controller: scrollCtrl,
          padding: EdgeInsets.zero,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [sc.withValues(alpha: 0.15), sc.withValues(alpha: 0.03)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: sc.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(Icons.shield_rounded, size: 32, color: sc)),
                const SizedBox(height: 12),
                Text(prov['name'] ?? 'Provider', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cs.onSurface)),
                const SizedBox(height: 6),
                _StatusChip(label: active ? 'Active' : 'Inactive', color: sc),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if ((prov['code'] ?? '').toString().isNotEmpty)
                  _InfoTile(icon: Icons.tag_rounded, label: 'Code', value: prov['code']),
                if ((prov['contact_person'] ?? '').toString().isNotEmpty)
                  _InfoTile(icon: Icons.person_rounded, label: 'Contact', value: prov['contact_person']),
                if ((prov['phone'] ?? '').toString().isNotEmpty)
                  _InfoTile(icon: Icons.phone_rounded, label: 'Phone', value: prov['phone']),
                if ((prov['email'] ?? '').toString().isNotEmpty)
                  _InfoTile(icon: Icons.email_rounded, label: 'Email', value: prov['email']),
                if ((prov['claim_email'] ?? '').toString().isNotEmpty)
                  _InfoTile(icon: Icons.mark_email_read_rounded, label: 'Claims Email', value: prov['claim_email']),
                _InfoTile(icon: Icons.schedule_rounded, label: 'Payment Terms', value: '${prov['payment_terms_days'] ?? 30} days'),
                _InfoTile(icon: Icons.percent_rounded, label: 'Discount Rate', value: '${prov['discount_rate'] ?? 0}%'),
                if ((prov['address'] ?? '').toString().isNotEmpty)
                  _InfoTile(icon: Icons.location_on_rounded, label: 'Address', value: prov['address']),

                const SizedBox(height: 12),
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Expanded(child: _FinancialTile(label: 'Open Claims', value: '${prov['open_claims'] ?? 0}', color: const Color(0xFFF59E0B))),
                    Expanded(child: _FinancialTile(label: 'Outstanding', value: _fmtMoney(prov['total_outstanding']), color: const Color(0xFFEF4444))),
                  ]),
                ),

                if ((prov['notes'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.2))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.note_rounded, size: 16, color: Color(0xFF0369A1)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(prov['notes'], style: const TextStyle(fontSize: 13, color: Color(0xFF0369A1)))),
                    ]),
                  ),
                ],
              ]),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Provider actions — long press ──
void _showProviderActions(BuildContext context, dynamic prov, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          ListTile(leading: const Icon(Icons.visibility_rounded, color: Color(0xFF3B82F6)),
            title: const Text('View Details'),
            onTap: () { Navigator.pop(ctx); _showProviderDetail(context, prov, ref); }),
          ListTile(leading: const Icon(Icons.edit_rounded, color: Color(0xFFF59E0B)),
            title: const Text('Edit'),
            onTap: () { Navigator.pop(ctx); _showProviderDialog(context, ref, provider: prov); }),
          ListTile(
            leading: Icon(prov['is_active'] == true ? Icons.toggle_off_rounded : Icons.toggle_on_rounded,
              color: prov['is_active'] == true ? Colors.grey : const Color(0xFF10B981)),
            title: Text(prov['is_active'] == true ? 'Deactivate' : 'Activate'),
            onTap: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(dioProvider).patch('/insurance/providers/${prov['id']}/', data: {'is_active': !(prov['is_active'] == true)});
                ref.invalidate(_insuranceProvidersProvider);
                if (context.mounted) _snack(context, prov['is_active'] == true ? 'Provider deactivated' : 'Provider activated', const Color(0xFF10B981));
              } catch (_) { if (context.mounted) _snack(context, 'Failed', Colors.red); }
            },
          ),
          ListTile(leading: const Icon(Icons.delete_rounded, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(ctx);
              final ok = await _confirm(context, 'Delete Provider?', 'This cannot be undone.');
              if (!ok || !context.mounted) return;
              try {
                await ref.read(dioProvider).delete('/insurance/providers/${prov['id']}/');
                ref.invalidate(_insuranceProvidersProvider);
                if (context.mounted) _snack(context, 'Provider deleted', Colors.grey);
              } catch (_) { if (context.mounted) _snack(context, 'Failed to delete', Colors.red); }
            }),
        ]),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  CREATE / EDIT PROVIDER
// ═══════════════════════════════════════════════════════════════════════════
void _showProviderDialog(BuildContext context, WidgetRef ref, {dynamic provider}) {
  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => _ProviderFormSheet(ref: ref, provider: provider));
}

class _ProviderFormSheet extends StatefulWidget {
  const _ProviderFormSheet({required this.ref, this.provider});
  final WidgetRef ref;
  final dynamic provider;
  @override
  State<_ProviderFormSheet> createState() => _ProviderFormSheetState();
}

class _ProviderFormSheetState extends State<_ProviderFormSheet> {
  late final TextEditingController _nameCtrl, _codeCtrl, _contactCtrl, _phoneCtrl,
    _emailCtrl, _claimEmailCtrl, _discountCtrl, _termsCtrl, _addressCtrl, _notesCtrl;
  bool _isActive = true;
  bool _saving = false;
  bool get _isEdit => widget.provider != null;

  @override
  void initState() {
    super.initState();
    final p = widget.provider;
    _nameCtrl = TextEditingController(text: p?['name'] ?? '');
    _codeCtrl = TextEditingController(text: p?['code'] ?? '');
    _contactCtrl = TextEditingController(text: p?['contact_person'] ?? '');
    _phoneCtrl = TextEditingController(text: p?['phone'] ?? '');
    _emailCtrl = TextEditingController(text: p?['email'] ?? '');
    _claimEmailCtrl = TextEditingController(text: p?['claim_email'] ?? '');
    _discountCtrl = TextEditingController(text: '${p?['discount_rate'] ?? 0}');
    _termsCtrl = TextEditingController(text: '${p?['payment_terms_days'] ?? 30}');
    _addressCtrl = TextEditingController(text: p?['address'] ?? '');
    _notesCtrl = TextEditingController(text: p?['notes'] ?? '');
    _isActive = p?['is_active'] ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _codeCtrl.dispose(); _contactCtrl.dispose(); _phoneCtrl.dispose();
    _emailCtrl.dispose(); _claimEmailCtrl.dispose(); _discountCtrl.dispose(); _termsCtrl.dispose();
    _addressCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = _isEdit ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    return DraggableScrollableSheet(
      initialChildSize: 0.92, maxChildSize: 0.95, minChildSize: 0.5,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.shield_rounded, color: accent, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Text(_isEdit ? 'Edit Provider' : 'New Provider', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
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
                _buildField('Name *', _nameCtrl, hint: 'Provider name'),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _buildField('Code', _codeCtrl, hint: 'e.g. NHIF')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField('Contact Person', _contactCtrl)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _buildField('Phone', _phoneCtrl, keyboard: TextInputType.phone)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField('Email', _emailCtrl, keyboard: TextInputType.emailAddress)),
                ]),
                const SizedBox(height: 16),
                _buildField('Claims Email', _claimEmailCtrl, keyboard: TextInputType.emailAddress, hint: 'claims@provider.com'),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _buildField('Discount %', _discountCtrl, keyboard: const TextInputType.numberWithOptions(decimal: true))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildField('Payment Terms (days)', _termsCtrl, keyboard: TextInputType.number)),
                ]),
                const SizedBox(height: 16),
                _buildField('Address', _addressCtrl, maxLines: 2),
                const SizedBox(height: 16),
                _buildField('Notes', _notesCtrl, maxLines: 2),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active', style: TextStyle(fontWeight: FontWeight.w600)),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(_isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
                  label: Text(_saving ? 'Saving...' : (_isEdit ? 'Save Changes' : 'Create Provider')),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
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
    if (_nameCtrl.text.trim().isEmpty) { _snack(context, 'Name is required', Colors.orange); return; }
    setState(() => _saving = true);
    try {
      final dio = widget.ref.read(dioProvider);
      final body = {
        'name': _nameCtrl.text.trim(),
        'code': _codeCtrl.text,
        'contact_person': _contactCtrl.text,
        'phone': _phoneCtrl.text,
        'email': _emailCtrl.text,
        'claim_email': _claimEmailCtrl.text,
        'discount_rate': double.tryParse(_discountCtrl.text) ?? 0,
        'payment_terms_days': int.tryParse(_termsCtrl.text) ?? 30,
        'address': _addressCtrl.text,
        'notes': _notesCtrl.text,
        'is_active': _isActive,
      };
      if (_isEdit) {
        await dio.patch('/insurance/providers/${widget.provider['id']}/', data: body);
      } else {
        await dio.post('/insurance/providers/', data: body);
      }
      widget.ref.invalidate(_insuranceProvidersProvider);
      if (mounted) {
        Navigator.pop(context);
        _snack(context, _isEdit ? 'Provider updated' : 'Provider created', const Color(0xFF10B981));
      }
    } on DioException catch (e) {
      if (mounted) _snackErr(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════════════════
Future<bool> _confirm(BuildContext context, String title, String content) async {
  return await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    title: Text(title), content: Text(content),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
    ],
  )) ?? false;
}

void _snack(BuildContext context, String msg, Color color) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating, backgroundColor: color));
}

void _snackErr(BuildContext context, DioException e) {
  final d = e.response?.data;
  String msg = 'Request failed';
  if (d is Map) {
    final parts = <String>[];
    for (final entry in d.entries) {
      final val = entry.value;
      parts.add(val is List ? '${entry.key}: ${val.join(', ')}' : '${entry.key}: $val');
    }
    if (parts.isNotEmpty) msg = parts.join('\n');
  } else if (d is String && d.isNotEmpty) { msg = d; }
  _snack(context, msg, Colors.red);
}
