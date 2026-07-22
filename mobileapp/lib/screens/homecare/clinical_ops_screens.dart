import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api.dart';
import 'hc_common.dart';

// ═════════════════ TELECONSULT ═════════════════
final _roomsProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/teleconsult-rooms/',
      params: {'page_size': 100});
});

class HomecareTeleconsultScreen extends ConsumerWidget {
  const HomecareTeleconsultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(_roomsProvider);
    return HcAsyncBody(
      value: rooms,
      onRefresh: () async => ref.refresh(_roomsProvider.future),
      builder: (list) {
        final rows = list.cast<Map>();
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: 'TELEHEALTH',
              title: 'Teleconsult',
              subtitle: 'Video rooms for remote consultations',
              icon: Icons.videocam_rounded,
              gradient: const [
                Color(0xFF3730A3),
                Color(0xFF4F46E5),
                Color(0xFF6366F1)
              ],
              chips: [
                HcHeroChip(
                    icon: Icons.meeting_room_rounded,
                    label: '${rows.length} rooms'),
              ],
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('No teleconsult rooms.')),
              )
            else
              ...rows.map((r) {
                final active = r['is_active'] == true || r['active'] == true;
                final url = (r['room_url'] ?? r['join_url'] ?? '').toString();
                return Card(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: ListTile(
                    leading: const Icon(Icons.videocam_rounded,
                        color: hcIndigo),
                    title: Text(
                        (r['name'] ?? r['patient_name'] ?? 'Room #${r['id']}')
                            .toString(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13.5)),
                    subtitle: Text(
                        '${r['patient_name'] ?? ''}${r['created_at'] != null ? ' · ${hcDate(r['created_at'])}' : ''}',
                        style: const TextStyle(fontSize: 11.5)),
                    trailing: url.isNotEmpty
                        ? FilledButton.tonal(
                            style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact),
                            onPressed: () => launchUrl(Uri.parse(url),
                                mode: LaunchMode.externalApplication),
                            child: const Text('Join'),
                          )
                        : HcStatusChip(
                            label: active ? 'ACTIVE' : 'CLOSED',
                            color: active ? hcGreen : hcSlate),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

// ═════════════════ CONSENTS ═════════════════
final _consentsProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/consents/', params: {'page_size': 200});
});
final _consentPatientsProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/patients/', params: {'page_size': 500});
});

const _scopeMeta = {
  'records':        {'label': 'Medical records',            'icon': Icons.description_rounded,      'color': Color(0xFF0D9488)},
  'medication':     {'label': 'Medication administration',  'icon': Icons.medication_rounded,        'color': Color(0xFF7C3AED)},
  'insurance':      {'label': 'Insurance billing',          'icon': Icons.shield_rounded,            'color': Color(0xFF0284C7)},
  'teleconsult':    {'label': 'Teleconsult recording',      'icon': Icons.videocam_rounded,          'color': Color(0xFF059669)},
  'data_analytics': {'label': 'Data analytics',             'icon': Icons.bar_chart_rounded,         'color': Color(0xFFF59E0B)},
};

const _scopeOptions = ['records', 'medication', 'insurance', 'teleconsult', 'data_analytics'];
const _relationshipOptions = [
  'Self', 'Parent', 'Guardian', 'Spouse', 'Child', 'Sibling',
  'Next of kin', 'Legal representative', 'Power of attorney', 'Caregiver', 'Other'
];

String _scopeLabel(String? s) => _scopeMeta[s]?['label'] as String? ?? (s ?? '—');
IconData _scopeIcon(String? s) => _scopeMeta[s]?['icon'] as IconData? ?? Icons.fact_check_rounded;
Color _scopeColor(String? s) => _scopeMeta[s]?['color'] as Color? ?? hcSlate;

bool _isExpiringSoon(Map c) {
  if (c['expires_at'] == null || c['revoked_at'] != null) return false;
  final d = DateTime.tryParse(c['expires_at'].toString());
  if (d == null) return false;
  final days = d.difference(DateTime.now()).inDays;
  return days >= 0 && days <= 30;
}

String _statusLabel(Map c) {
  if (c['revoked_at'] != null) return 'revoked';
  if (_isExpiringSoon(c)) return 'expiring';
  return 'active';
}

Color _statusColor(Map c) {
  final s = _statusLabel(c);
  return s == 'revoked' ? hcRed : s == 'expiring' ? hcAmber : hcGreen;
}

String _expiryLabel(Map c) {
  if (c['expires_at'] == null) return '';
  final d = DateTime.tryParse(c['expires_at'].toString());
  if (d == null) return '';
  final days = d.difference(DateTime.now()).inDays;
  if (days < 0) return 'Expired ${-days}d ago';
  if (days == 0) return 'Expires today';
  return 'Expires in ${days}d';
}

class HomecareConsentsScreen extends ConsumerStatefulWidget {
  const HomecareConsentsScreen({super.key});

  @override
  ConsumerState<HomecareConsentsScreen> createState() =>
      _HomecareConsentsScreenState();
}

class _HomecareConsentsScreenState extends ConsumerState<HomecareConsentsScreen> {
  String _search = '';
  String _filterScope = '';
  String _filterStatus = 'all'; // all | active | expiring | revoked

  @override
  Widget build(BuildContext context) {
    final consents = ref.watch(_consentsProvider);
    final cs = Theme.of(context).colorScheme;
    return HcAsyncBody(
      value: consents,
      onRefresh: () async => ref.refresh(_consentsProvider.future),
      builder: (list) {
        final allRows = list.cast<Map>().toList();
        final activeCount = allRows.where((c) => c['revoked_at'] == null).length;
        final revokedCount = allRows.length - activeCount;
        final expiringCount = allRows.where(_isExpiringSoon).length;

        var rows = allRows;
        if (_filterScope.isNotEmpty) {
          rows = rows.where((c) => c['scope'] == _filterScope).toList();
        }
        if (_filterStatus == 'active') {
          rows = rows.where((c) => c['revoked_at'] == null && !_isExpiringSoon(c)).toList();
        } else if (_filterStatus == 'expiring') {
          rows = rows.where(_isExpiringSoon).toList();
        } else if (_filterStatus == 'revoked') {
          rows = rows.where((c) => c['revoked_at'] != null).toList();
        }
        if (_search.isNotEmpty) {
          final q = _search.toLowerCase();
          rows = rows.where((c) =>
              (c['patient_name'] ?? '').toString().toLowerCase().contains(q) ||
              (c['granted_to'] ?? '').toString().toLowerCase().contains(q)).toList();
        }

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _buildHero(cs, allRows.length, activeCount, expiringCount, revokedCount),
            _buildStatTiles(cs, allRows.length, activeCount, expiringCount, revokedCount),
            _buildSearchAndFilters(cs),
            // ── Scope breakdown ──
            _buildScopeBreakdown(cs, allRows),
            // ── Expiring soon ──
            if (allRows.where(_isExpiringSoon).isNotEmpty)
              _buildExpiringSoon(cs, allRows.where(_isExpiringSoon).take(5).toList()),
            // ── Consent cards ──
            if (rows.isEmpty)
              _buildEmptyState(cs)
            else
              ...rows.map((c) => _ConsentCard(
                    consent: c,
                    onView: () => _openView(c),
                    onRevoke: () => _openRevoke(c),
                    onSign: () => _openSign(c),
                  )),
          ],
        );
      },
    );
  }

  // ── Premium hero ──
  Widget _buildHero(ColorScheme cs, int total, int active, int expiring, int revoked) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF0F766E), Color(0xFF14B8A6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: hcTeal.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 14))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.fact_check_rounded, color: Colors.white, size: 28),
          ),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: hcTeal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            onPressed: () => _openCreate(),
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: const Text('Sign new', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 16),
        Text('COMPLIANCE',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
        const SizedBox(height: 4),
        const Text('Consents', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Patient consent records governing data sharing, treatment and analytics.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13, height: 1.4)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _heroChip(Icons.check_circle_rounded, '$active active'),
          _heroChip(Icons.schedule_rounded, '$expiring expiring'),
          _heroChip(Icons.cancel_rounded, '$revoked revoked'),
        ]),
      ]),
    );
  }

  Widget _heroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Stat tiles ──
  Widget _buildStatTiles(ColorScheme cs, int total, int active, int expiring, int revoked) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: [
        Expanded(child: _ConsentStatTile(icon: Icons.fact_check_rounded, label: 'Total', value: '$total', color: hcTeal,
          active: _filterStatus == 'all' && _filterScope.isEmpty,
          onTap: () => setState(() { _filterStatus = 'all'; _filterScope = ''; }))),
        const SizedBox(width: 8),
        Expanded(child: _ConsentStatTile(icon: Icons.check_circle_rounded, label: 'Active', value: '$active', color: hcGreen,
          active: _filterStatus == 'active',
          onTap: () => setState(() => _filterStatus = _filterStatus == 'active' ? 'all' : 'active'))),
        const SizedBox(width: 8),
        Expanded(child: _ConsentStatTile(icon: Icons.schedule_rounded, label: 'Expiring', value: '$expiring', color: hcAmber,
          active: _filterStatus == 'expiring',
          onTap: () => setState(() => _filterStatus = _filterStatus == 'expiring' ? 'all' : 'expiring'))),
        const SizedBox(width: 8),
        Expanded(child: _ConsentStatTile(icon: Icons.cancel_rounded, label: 'Revoked', value: '$revoked', color: hcRed,
          active: _filterStatus == 'revoked',
          onTap: () => setState(() => _filterStatus = _filterStatus == 'revoked' ? 'all' : 'revoked'))),
      ]),
    );
  }

  // ── Search + filters ──
  Widget _buildSearchAndFilters(ColorScheme cs) {
    return Column(children: [
      // Search
      Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search patient or grantee…',
            prefixIcon: Icon(Icons.search_rounded, color: cs.onSurfaceVariant, size: 22),
            suffixIcon: _search.isNotEmpty
                ? IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => setState(() => _search = ''))
                : null,
            filled: true, fillColor: Colors.transparent,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            isDense: true, hintStyle: TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant),
          ),
        ),
      ),
      // Scope filter chips
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _scopeChip(cs, 'All', '', hcTeal),
              ..._scopeOptions.map((s) => _scopeChip(cs, _scopeLabel(s), s, _scopeColor(s))),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _scopeChip(ColorScheme cs, String label, String scope, Color color) {
    final active = _filterScope == scope;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? Colors.white : cs.onSurfaceVariant)),
        selected: active,
        onSelected: (v) => setState(() => _filterScope = v ? scope : ''),
        selectedColor: color,
        backgroundColor: cs.surfaceContainerHighest,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        showCheckmark: false,
      ),
    );
  }

  // ── Scope breakdown ──
  Widget _buildScopeBreakdown(ColorScheme cs, List<Map> allRows) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: hcPurple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.donut_small_rounded, color: hcPurple, size: 18)),
          const SizedBox(width: 10),
          const Text('By scope', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const Spacer(),
          Text('${allRows.length} total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        ]),
        const SizedBox(height: 12),
        ..._scopeOptions.map((s) {
          final count = allRows.where((c) => c['scope'] == s).length;
          final pct = allRows.isEmpty ? 0.0 : count / allRows.length;
          final color = _scopeColor(s);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(width: 28, height: 28, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(_scopeIcon(s), size: 15, color: color)),
              const SizedBox(width: 10),
              Expanded(child: Text(_scopeLabel(s), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: cs.surfaceContainerHighest, color: color),
                ),
              ),
              const SizedBox(width: 6),
              Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
            ]),
          );
        }),
      ]),
    );
  }

  // ── Expiring soon ──
  Widget _buildExpiringSoon(ColorScheme cs, List<Map> items) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hcAmber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hcAmber.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: hcAmber.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.schedule_rounded, color: hcAmber, size: 18)),
          const SizedBox(width: 10),
          const Text('Expiring soon', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
        const SizedBox(height: 10),
        ...items.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Icon(Icons.person_rounded, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(c['patient_name']?.toString() ?? '—', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text('${_scopeLabel(c['scope']?.toString())} · ${_expiryLabel(c)}',
                style: TextStyle(fontSize: 11, color: hcAmber, fontWeight: FontWeight.w600)),
          ]),
        )),
      ]),
    );
  }

  // ── Empty state ──
  Widget _buildEmptyState(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [hcTeal.withValues(alpha: 0.12), hcTeal.withValues(alpha: 0.04)]),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.fact_check_rounded, size: 38, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 16),
            const Text('No consents', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 6),
            Text('Sign a new consent to get started.', style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: hcTeal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => _openCreate(),
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: const Text('Sign new consent'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Create ──
  void _openCreate() {
    final patients = ref.read(_consentPatientsProvider).valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _ConsentFormSheet(
        patients: patients.cast<Map>().toList(),
        onSubmit: (payload, sigPad, signerName, relationship) async {
          final dio = ref.read(dioProvider);
          final messenger = ScaffoldMessenger.of(context);
          try {
            final res = await dio.post('/homecare/consents/', data: payload);
            final consentId = res.data['id'];
            try {
              final dataUrl = await sigPad.toDataUrl();
              await dio.post('/homecare/consents/$consentId/sign/', data: {
                'signature_data_url': dataUrl,
                'signed_by_name': signerName,
                'signed_by_relationship': relationship,
              });
            } catch (_) {}
            ref.invalidate(_consentsProvider);
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) {
              messenger.showSnackBar(SnackBar(
                content: const Text('Consent signed'), backgroundColor: hcGreen,
                behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ));
            }
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: const Text('Failed to create consent'), backgroundColor: hcRed,
                behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ));
            }
          }
        },
      ),
    );
  }

  // ── View ──
  void _openView(Map c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _ConsentViewSheet(consent: c),
    );
  }

  // ── Revoke ──
  void _openRevoke(Map c) {
    final reasonCtrl = TextEditingController();
    bool revoking = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.cancel_rounded, color: hcRed, size: 22),
          const SizedBox(width: 10),
          const Text('Revoke consent', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(TextSpan(children: [
            const TextSpan(text: 'Revoke '),
            TextSpan(text: _scopeLabel(c['scope']?.toString()), style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: ' consent for '),
            TextSpan(text: c['patient_name']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: '?'),
          ]), style: const TextStyle(fontSize: 13.5)),
          const SizedBox(height: 14),
          TextField(
            controller: reasonCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Reason', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              hintText: 'e.g. Patient withdrew consent…',
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: hcRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: revoking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.cancel_rounded, size: 18),
            label: const Text('Revoke'),
            onPressed: revoking ? null : () async {
              setState(() => revoking = true);
              try {
                final dio = ref.read(dioProvider);
                await dio.post('/homecare/consents/${c['id']}/revoke/', data: {'reason': reasonCtrl.text.trim()});
                ref.invalidate(_consentsProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Consent revoked'), backgroundColor: hcAmber,
                    behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ));
                }
              } catch (_) {
                setState(() => revoking = false);
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Revoke failed'), backgroundColor: hcRed));
                }
              }
            },
          ),
        ],
      )),
    );
  }

  // ── Sign ──
  void _openSign(Map c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _ConsentSignSheet(
        consent: c,
        onSubmit: (sigPad, signerName, relationship) async {
          final dio = ref.read(dioProvider);
          final messenger = ScaffoldMessenger.of(context);
          try {
            final dataUrl = await sigPad.toDataUrl();
            await dio.post('/homecare/consents/${c['id']}/sign/', data: {
              'signature_data_url': dataUrl,
              'signed_by_name': signerName,
              'signed_by_relationship': relationship,
            });
            ref.invalidate(_consentsProvider);
            if (ctx.mounted) Navigator.pop(ctx);
            if (mounted) {
              messenger.showSnackBar(SnackBar(
                content: const Text('Consent signed'), backgroundColor: hcGreen,
                behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ));
            }
          } catch (_) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: const Text('Signature failed'), backgroundColor: hcRed,
                behavior: SnackBarBehavior.floating, margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ));
            }
          }
        },
      ),
    );
  }
}

// ═════════════════ Consent widgets ═════════════════

// ── Stat tile ──
class _ConsentStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _ConsentStatTile({required this.icon, required this.label, required this.value, required this.color, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.08) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: active ? Border.all(color: color.withValues(alpha: 0.35), width: 1.5) : null,
        boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, letterSpacing: 0.3)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Consent card ──
class _ConsentCard extends StatelessWidget {
  final Map consent;
  final VoidCallback onView;
  final VoidCallback onRevoke;
  final VoidCallback onSign;
  const _ConsentCard({required this.consent, required this.onView, required this.onRevoke, required this.onSign});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scope = consent['scope']?.toString();
    final color = _scopeColor(scope);
    final isRevoked = consent['revoked_at'] != null;
    final isSigned = consent['signed_at'] != null || (consent['signature_hash'] ?? '').toString().isNotEmpty;
    final statusLabel = _statusLabel(consent);
    final statusColor = _statusColor(consent);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Scope band
          Container(height: 3, color: color),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header row
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                  child: Icon(_scopeIcon(scope), size: 22, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(_scopeLabel(scope),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      HcStatusChip(label: statusLabel.toUpperCase(), color: statusColor),
                    ]),
                    const SizedBox(height: 3),
                    if ((consent['granted_to'] ?? '').toString().isNotEmpty)
                      Row(children: [
                        Icon(Icons.arrow_forward_rounded, size: 12, color: cs.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Text(consent['granted_to'].toString(),
                            style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                      ]),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              // Info row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.person_rounded, size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(consent['patient_name']?.toString() ?? '—',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.calendar_month_rounded, size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 3),
                  Text(hcDate(consent['signed_at'] ?? consent['granted_at']),
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ]),
              ),
              // Expiry
              if (consent['expires_at'] != null && !isRevoked) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.schedule_rounded, size: 13,
                      color: _isExpiringSoon(consent) ? hcAmber : cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(_expiryLabel(consent),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: _isExpiringSoon(consent) ? hcAmber : cs.onSurfaceVariant)),
                ]),
              ],
              // Notes
              if ((consent['notes'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
                  child: Text(consent['notes'].toString(),
                      style: TextStyle(fontSize: 12, height: 1.3, color: cs.onSurfaceVariant),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ],
              const SizedBox(height: 10),
              // Action row
              Row(children: [
                if (isSigned)
                  HcStatusChip(label: 'E-SIGNED', color: hcGreen, icon: Icons.verified_rounded)
                else if (!isRevoked)
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: hcTeal.withValues(alpha: 0.12),
                      foregroundColor: hcTeal,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: onSign,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.draw_rounded, size: 15),
                      const SizedBox(width: 4),
                      const Text('Sign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                const Spacer(),
                if (!isRevoked)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: hcRed, padding: const EdgeInsets.symmetric(horizontal: 10)),
                    onPressed: onRevoke,
                    icon: const Icon(Icons.cancel_rounded, size: 17),
                    label: const Text('Revoke', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: hcTeal, padding: const EdgeInsets.symmetric(horizontal: 10)),
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_rounded, size: 17),
                  label: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════ Signature pad ═════════════════
class _SignaturePad extends StatefulWidget {
  final double height;
  const _SignaturePad({super.key, this.height = 160});

  @override
  State<_SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<_SignaturePad> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];

  bool get hasInk => _strokes.isNotEmpty;

  void clear() {
    setState(() { _strokes.clear(); _currentStroke.clear(); });
  }

  Future<String> toDataUrl() async {
    final w = 300, h = widget.height.round();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    final paint = ui.Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2.5
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round
      ..style = ui.PaintingStyle.stroke;
    for (final stroke in _strokes) {
      if (stroke.length < 2) continue;
      final path = ui.Path()..moveTo(stroke[0].dx, stroke[0].dy);
      for (final p in stroke) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
    final picture = recorder.endRecording();
    final img = await picture.toImage(w, h);
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (pngBytes == null) return '';
    final base64Str = base64Encode(pngBytes.buffer.asUint8List());
    return 'data:image/png;base64,$base64Str';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: hcTeal.withValues(alpha: 0.4), width: 2, strokeAlign: BorderSide.strokeAlignOutside),
        borderRadius: BorderRadius.circular(14),
        color: cs.surface,
      ),
      child: GestureDetector(
        onPanStart: (d) {
          setState(() { _currentStroke = [d.localPosition]; });
        },
        onPanUpdate: (d) {
          setState(() { _currentStroke.add(d.localPosition); });
        },
        onPanEnd: (_) {
          setState(() { _strokes.add(List.from(_currentStroke)); _currentStroke.clear(); });
        },
        child: SizedBox(
          height: widget.height,
          child: CustomPaint(
            painter: _SignaturePainter(_strokes, _currentStroke),
            child: Stack(children: [
              if (_strokes.isEmpty && _currentStroke.isEmpty)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.draw_rounded, size: 28, color: cs.onSurfaceVariant.withValues(alpha: 0.25)),
                      const SizedBox(height: 4),
                      Text('Sign here', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.35), fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> current;
  _SignaturePainter(this.strokes, this.current);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke[0].dx, stroke[0].dy);
      for (final p in stroke) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
    if (current.length >= 2) {
      final path = Path()..moveTo(current[0].dx, current[0].dy);
      for (final p in current) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}

// ═════════════════ Consent form sheet (create) ═════════════════
class _ConsentFormSheet extends StatefulWidget {
  final List<Map> patients;
  final Future<void> Function(Map<String, dynamic> payload, _SignaturePadState sigPad, String signerName, String relationship) onSubmit;
  const _ConsentFormSheet({required this.patients, required this.onSubmit});

  @override
  State<_ConsentFormSheet> createState() => _ConsentFormSheetState();
}

class _ConsentFormSheetState extends State<_ConsentFormSheet> {
  int? _patientId;
  String _scope = 'records';
  final _grantedTo = TextEditingController();
  DateTime? _expiresAt;
  final _notes = TextEditingController();
  final _signerName = TextEditingController();
  String _relationship = 'Self';
  final _sigKey = GlobalKey<_SignaturePadState>();
  bool _saving = false;

  @override
  void dispose() {
    _grantedTo.dispose();
    _notes.dispose();
    _signerName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF0F766E)], begin: Alignment.topLeft, end: Alignment.topRight),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Handle bar
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              // Title
              Row(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: hcTeal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.edit_note_rounded, color: hcTeal, size: 22)),
                const SizedBox(width: 12),
                const Text('New consent', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ]),
              const SizedBox(height: 20),
              // Patient picker
              DropdownButtonFormField<int>(
                initialValue: _patientId,
                decoration: InputDecoration(labelText: 'Patient *', prefixIcon: Icon(Icons.person_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                items: widget.patients.map((p) => DropdownMenuItem(
                  value: p['id'] as int?,
                  child: Text('${p['user']?['full_name'] ?? p['name'] ?? 'Patient'}${p['medical_record_number'] != null ? ' · ${p['medical_record_number']}' : ''}',
                      overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                )).toList(),
                onChanged: (v) => setState(() => _patientId = v),
              ),
              const SizedBox(height: 12),
              // Scope
              DropdownButtonFormField<String>(
                initialValue: _scope,
                decoration: InputDecoration(labelText: 'Scope *', prefixIcon: Icon(Icons.shield_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                items: _scopeOptions.map((s) => DropdownMenuItem(value: s, child: Text(_scopeLabel(s), style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _scope = v ?? 'records'),
              ),
              const SizedBox(height: 12),
              // Granted to
              TextField(
                controller: _grantedTo,
                decoration: InputDecoration(labelText: 'Granted to', hintText: 'Clinic, pharmacy, insurer…',
                    prefixIcon: Icon(Icons.arrow_forward_rounded, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
              ),
              const SizedBox(height: 12),
              // Expires at
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 365)), firstDate: DateTime.now(), lastDate: DateTime(2100));
                  if (d != null) setState(() => _expiresAt = d);
                },
                child: InputDecorator(
                  decoration: InputDecoration(labelText: 'Expires at', prefixIcon: Icon(Icons.calendar_month_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text(_expiresAt == null ? 'No expiry' : '${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}',
                      style: TextStyle(fontSize: 14, color: _expiresAt == null ? cs.onSurfaceVariant : cs.onSurface)),
                ),
              ),
              const SizedBox(height: 12),
              // Notes
              TextField(
                controller: _notes, maxLines: 2,
                decoration: InputDecoration(labelText: 'Notes', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
              ),
              const SizedBox(height: 20),
              // Signature section
              Row(children: [
                Icon(Icons.draw_rounded, color: hcTeal, size: 18),
                const SizedBox(width: 6),
                const Text('Digital signature', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: hcRed.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
                    child: Text('required', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: hcRed))),
              ]),
              const SizedBox(height: 4),
              Text('Capture the patient / guardian signature to e-sign this consent.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              // Signer name
              TextField(
                controller: _signerName,
                decoration: InputDecoration(labelText: 'Signer full name *', prefixIcon: Icon(Icons.person_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
              ),
              const SizedBox(height: 10),
              // Relationship
              DropdownButtonFormField<String>(
                initialValue: _relationship,
                decoration: InputDecoration(labelText: 'Relationship to patient *', prefixIcon: Icon(Icons.group_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                items: _relationshipOptions.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _relationship = v ?? 'Self'),
              ),
              const SizedBox(height: 10),
              // Signature pad
              _SignaturePad(key: _sigKey, height: 140),
              const SizedBox(height: 6),
              Row(children: [
                TextButton.icon(
                  onPressed: () => _sigKey.currentState?.clear(),
                  icon: Icon(Icons.cleaning_services_rounded, size: 16, color: cs.onSurfaceVariant),
                  label: Text('Clear', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ),
                const Spacer(),
                Text('By signing you confirm consent under applicable laws.',
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ]),
              const SizedBox(height: 16),
              // Submit
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: hcTeal, padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: _saving ? null : () async {
                      if (_patientId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient is required')));
                        return;
                      }
                      if (_signerName.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signer name is required')));
                        return;
                      }
                      if (_sigKey.currentState?.hasInk != true) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in the box')));
                        return;
                      }
                      setState(() => _saving = true);
                      final payload = {
                        'patient': _patientId,
                        'scope': _scope,
                        'granted_to': _grantedTo.text.trim(),
                        'expires_at': _expiresAt != null ? '${_expiresAt!.year}-${_expiresAt!.month.toString().padLeft(2, '0')}-${_expiresAt!.day.toString().padLeft(2, '0')}' : null,
                        'notes': _notes.text.trim(),
                      };
                      await widget.onSubmit(payload, _sigKey.currentState!, _signerName.text.trim(), _relationship);
                      if (mounted) setState(() => _saving = false);
                    },
                    icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded, size: 20),
                    label: const Text('Save consent', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═════════════════ Consent sign sheet ═════════════════
class _ConsentSignSheet extends StatefulWidget {
  final Map consent;
  final Future<void> Function(_SignaturePadState sigPad, String signerName, String relationship) onSubmit;
  const _ConsentSignSheet({required this.consent, required this.onSubmit});

  @override
  State<_ConsentSignSheet> createState() => _ConsentSignSheetState();
}

class _ConsentSignSheetState extends State<_ConsentSignSheet> {
  final _signerName = TextEditingController();
  String _relationship = 'Self';
  final _sigKey = GlobalKey<_SignaturePadState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _signerName.text = widget.consent['patient_name']?.toString() ?? '';
  }

  @override
  void dispose() {
    _signerName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF0F766E)], begin: Alignment.topLeft, end: Alignment.topRight),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: hcTeal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.draw_rounded, color: hcTeal, size: 22)),
                const SizedBox(width: 12),
                const Text('Sign consent', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ]),
              const SizedBox(height: 8),
              Text.rich(TextSpan(children: [
                TextSpan(text: _scopeLabel(widget.consent['scope']?.toString()), style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(text: ' consent for '),
                TextSpan(text: widget.consent['patient_name']?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
              ]), style: TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              TextField(
                controller: _signerName,
                decoration: InputDecoration(labelText: 'Signer full name *', prefixIcon: Icon(Icons.person_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _relationship,
                decoration: InputDecoration(labelText: 'Relationship to patient *', prefixIcon: Icon(Icons.group_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
                items: _relationshipOptions.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _relationship = v ?? 'Self'),
              ),
              const SizedBox(height: 10),
              Text('Sign in the box below using your finger *', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const SizedBox(height: 6),
              _SignaturePad(key: _sigKey, height: 160),
              const SizedBox(height: 6),
              Row(children: [
                TextButton.icon(
                  onPressed: () => _sigKey.currentState?.clear(),
                  icon: Icon(Icons.cleaning_services_rounded, size: 16, color: cs.onSurfaceVariant),
                  label: Text('Clear', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ),
                const Spacer(),
                Text('By signing you confirm consent under applicable laws.',
                    style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: hcTeal, padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: _saving ? null : () async {
                      if (_signerName.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signer name required')));
                        return;
                      }
                      if (_sigKey.currentState?.hasInk != true) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in the box')));
                        return;
                      }
                      setState(() => _saving = true);
                      await widget.onSubmit(_sigKey.currentState!, _signerName.text.trim(), _relationship);
                      if (mounted) setState(() => _saving = false);
                    },
                    icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded, size: 20),
                    label: const Text('Apply signature', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

// ═════════════════ Consent view sheet ═════════════════
class _ConsentViewSheet extends StatelessWidget {
  final Map consent;
  const _ConsentViewSheet({required this.consent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scope = consent['scope']?.toString();
    final color = _scopeColor(scope);
    final isSigned = consent['signed_at'] != null || (consent['signature_hash'] ?? '').toString().isNotEmpty;
    final isRevoked = consent['revoked_at'] != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, controller) => Container(
        decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(children: [
          // Top bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [hcTeal.withValues(alpha: 0.08), hcPurple.withValues(alpha: 0.05)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Row(children: [
              Icon(Icons.description_rounded, color: hcTeal, size: 22),
              const SizedBox(width: 8),
              const Text('Consent document', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Scope band
                Container(height: 3, decoration: BoxDecoration(gradient: LinearGradient(colors: [color, hcPurple]), borderRadius: BorderRadius.circular(3))),
                const SizedBox(height: 16),
                // Title
                Text('Patient Consent Form', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: cs.onSurface)),
                const SizedBox(height: 2),
                Text('${_scopeLabel(scope)} · Ref #${consent['id']}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 20),
                // Details table
                _DetailRow(label: 'Patient', value: consent['patient_name']?.toString() ?? '—'),
                _DetailRow(label: 'Scope', value: _scopeLabel(scope)),
                _DetailRow(label: 'Granted to', value: consent['granted_to']?.toString() ?? '—'),
                _DetailRow(label: 'Status', value: _statusLabel(consent), valueColor: _statusColor(consent)),
                _DetailRow(label: 'Granted at', value: hcDateTime(consent['granted_at'])),
                _DetailRow(label: 'Expires at', value: consent['expires_at'] != null ? hcDate(consent['expires_at']) : '—'),
                if (isRevoked)
                  _DetailRow(label: 'Revoked at', value: hcDateTime(consent['revoked_at']), valueColor: hcRed),
                const SizedBox(height: 16),
                // Notes
                if ((consent['notes'] ?? '').toString().isNotEmpty) ...[
                  Text('Notes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                    child: Text(consent['notes'].toString(), style: TextStyle(fontSize: 12.5, height: 1.4, color: cs.onSurface)),
                  ),
                  const SizedBox(height: 16),
                ],
                // Declaration
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    'I, the undersigned, confirm that I have read and understood the scope of this consent and voluntarily grant permission as described above under applicable laws.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, height: 1.5, color: cs.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 20),
                // Signature block
                Text('Signature', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (consent['signature_data_url'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          consent['signature_data_url'].toString(),
                          height: 60, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Text('Not signed', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: cs.onSurfaceVariant)),
                        ),
                      )
                    else
                      SizedBox(
                        height: 60,
                        child: Center(child: Text('Not signed', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: cs.onSurfaceVariant))),
                      ),
                    const SizedBox(height: 8),
                    Container(height: 1, color: cs.outlineVariant),
                    const SizedBox(height: 6),
                    Text(
                      '${consent['signed_by_name'] ?? '—'}${consent['signed_by_relationship'] != null ? ' (${consent['signed_by_relationship']})' : ''}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text('Signed ${hcDateTime(consent['signed_at'])}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ]),
                ),
                if (isSigned) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: hcGreen.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Icon(Icons.verified_rounded, size: 16, color: hcGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Digitally signed · verified', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: hcGreen)),
                          if ((consent['signature_hash'] ?? '').toString().isNotEmpty)
                            Text('SHA-256: ${consent['signature_hash']}', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: valueColor ?? cs.onSurface))),
      ]),
    );
  }
}

// ═════════════════ PRESCRIPTIONS ═════════════════
final _rxProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/prescriptions/',
      params: {'page_size': 200});
});

class HomecarePrescriptionsScreen extends ConsumerWidget {
  const HomecarePrescriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rx = ref.watch(_rxProvider);
    return HcAsyncBody(
      value: rx,
      onRefresh: () async => ref.refresh(_rxProvider.future),
      builder: (list) {
        final rows = list.cast<Map>();
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: 'MEDICATIONS',
              title: 'Prescriptions',
              subtitle: 'Prescriptions routed to pharmacies',
              icon: Icons.receipt_rounded,
              gradient: const [
                Color(0xFF9D174D),
                Color(0xFFDB2777),
                Color(0xFFEC4899)
              ],
              chips: [
                HcHeroChip(
                    icon: Icons.receipt_long_rounded,
                    label: '${rows.length} prescriptions'),
              ],
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('No prescriptions.')),
              )
            else
              ...rows.map((r) {
                final status =
                    (r['pharmacy_status'] ?? r['status'] ?? '').toString();
                return Card(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: ListTile(
                    leading:
                        const Icon(Icons.receipt_rounded, color: hcRose),
                    title: Text(r['patient_name']?.toString() ?? '—',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13.5)),
                    subtitle: Text(
                        '${(r['medications'] as List?)?.length ?? r['items_count'] ?? '—'} items · ${hcDate(r['created_at'])}',
                        style: const TextStyle(fontSize: 11.5)),
                    trailing: HcStatusChip(
                        label: hcLabel(status),
                        color: status == 'dispensed' || status == 'completed'
                            ? hcGreen
                            : status == 'pending'
                                ? hcAmber
                                : hcBlue),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
