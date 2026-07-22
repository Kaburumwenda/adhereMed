import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/api.dart';
import 'dose_action_sheet.dart';
import 'hc_common.dart';

// ── Status metadata (mirrors web statusColor/statusIcon/statusDisplay) ──
class _StatusMeta {
  final String display;
  final IconData icon;
  final Color color;
  const _StatusMeta(this.display, this.icon, this.color);
}

_StatusMeta _statusMeta(String? s) => switch (s) {
      'pending' => const _StatusMeta('Pending', Icons.schedule_rounded, hcAmber),
      'taken' =>
        const _StatusMeta('Documented', Icons.task_alt_rounded, hcGreen),
      'missed' => const _StatusMeta('Missed', Icons.warning_rounded, hcRed),
      'skipped' =>
        const _StatusMeta('Skipped', Icons.skip_next_rounded, hcSlate),
      'not_given' =>
        const _StatusMeta('Not given', Icons.cancel_rounded, hcRed),
      'overdue' => const _StatusMeta('Overdue', Icons.priority_high_rounded, hcRed),
      _ => const _StatusMeta('—', Icons.circle_outlined, hcSlate),
    };

final _doseRange = StateProvider.autoDispose((_) => 'today');
final _doseStatus = StateProvider.autoDispose((_) => 'all');
final _doseSearch = StateProvider.autoDispose((_) => '');

final _dosesProvider = FutureProvider.autoDispose((ref) async {
  final range = ref.watch(_doseRange);
  final dio = ref.read(dioProvider);
  try {
    await dio.post('/homecare/doses/auto_expire/');
  } catch (_) {/* non-fatal */}

  if (range == 'today') {
    final res = await dio.get('/homecare/doses/today/', queryParameters: {'page_size': 1000});
    return (res.data is List ? res.data : (res.data['results'] ?? [])) as List;
  }

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime? from;
  DateTime? to;
  switch (range) {
    case 'yesterday':
      from = today.subtract(const Duration(days: 1));
      to = today;
    case 'last7':
      from = today.subtract(const Duration(days: 6));
      to = today.add(const Duration(days: 1));
    case 'last30':
      from = today.subtract(const Duration(days: 29));
      to = today.add(const Duration(days: 1));
    case 'thisMonth':
      from = DateTime(now.year, now.month, 1);
      to = DateTime(now.year, now.month + 1, 1);
    case 'upcoming':
      from = now;
    case 'overdue':
      to = now;
    case 'all':
      break;
  }
  return hcFetchAll(ref, '/homecare/doses/', params: {
    'page_size': 1000,
    if (from != null) 'from': from.toUtc().toIso8601String(),
    if (to != null) 'to': to.toUtc().toIso8601String(),
  });
});

const _dateRanges = [
  ('today', 'Today'),
  ('yesterday', 'Yesterday'),
  ('last7', 'Last 7 days'),
  ('last30', 'Last 30 days'),
  ('thisMonth', 'This month'),
  ('upcoming', 'Upcoming'),
  ('overdue', 'Overdue'),
  ('all', 'All'),
];

const _statusFilters = [
  ('all', 'All statuses'),
  ('pending', 'Pending'),
  ('taken', 'Documented'),
  ('missed', 'Missed'),
  ('skipped', 'Skipped'),
  ('not_given', 'Not given'),
  ('overdue', 'Overdue'),
];

/// Medication doses — mirrors the web /homecare/doses page.
class HomecareDosesScreen extends ConsumerStatefulWidget {
  const HomecareDosesScreen({super.key});

  @override
  ConsumerState<HomecareDosesScreen> createState() =>
      _HomecareDosesScreenState();
}

class _HomecareDosesScreenState extends ConsumerState<HomecareDosesScreen> {
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final doses = ref.watch(_dosesProvider);
    final range = ref.watch(_doseRange);
    final status = ref.watch(_doseStatus);
    final query = ref.watch(_doseSearch);

    return Scaffold(
      body: HcAsyncBody(
        value: doses,
        onRefresh: () async => ref.refresh(_dosesProvider.future),
        builder: (list) {
          final all = list.cast<Map>().toList();
          var filtered = all.where((d) {
            if (status != 'all' && d['status'] != status) return false;
            if (range == 'overdue' && d['status'] != 'pending') return false;
            if (query.isEmpty) return true;
            final q = query.toLowerCase();
            return [d['medication_name'], d['schedule_medication'], d['patient_name'], d['dose']]
                .any((v) => (v ?? '').toString().toLowerCase().contains(q));
          }).toList()
            ..sort((a, b) => (b['scheduled_at'] ?? '').toString().compareTo((a['scheduled_at'] ?? '').toString()));

          final taken = all.where((d) => d['status'] == 'taken').length;
          final missed = all.where((d) => d['status'] == 'missed').length;
          final pending = all.where((d) => d['status'] == 'pending').length;
          final skipped = all.where((d) => d['status'] == 'skipped').length;
          final notGiven = all.where((d) => d['status'] == 'not_given').length;
          final finalized = taken + missed;
          final adherence = finalized > 0 ? (taken / finalized * 100).round() : 0;

          final grouped = _group(filtered);

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _hero(all, pending, taken, adherence),
              _kpiStrip(all.length, pending, taken, missed),
              _filters(range, status),
              HcPanel(
                title: 'Doses timeline',
                subtitle: 'Grouped by hour · real-time adherence tracking',
                icon: Icons.timeline_rounded,
                color: hcTeal,
                action: Text('${filtered.length} dose${filtered.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(children: [
                            Icon(Icons.medication_liquid_outlined, size: 44,
                                color: Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(height: 8),
                            const Text('No doses found. Try a different filter or date range.'),
                          ]),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final g in grouped) ...[
                            _timeGroupHeader(g),
                            for (final d in g['list'] as List)
                              _DoseCard(
                                dose: d as Map,
                                expanded: _expanded.contains(d['id'] as int),
                                onToggle: () => setState(() {
                                  final id = d['id'] as int;
                                  if (_expanded.contains(id)) {
                                    _expanded.remove(id);
                                  } else {
                                    _expanded.add(id);
                                  }
                                }),
                                onAction: (type) => _openAction(d, type),
                              ),
                          ],
                        ],
                      ),
              ),
              _statusBreakdown(all, adherence, taken, missed, pending, skipped, notGiven),
              _adherenceByPatient(all),
            ],
          );
        },
      ),
    );
  }

  // ── Hero ──
  Widget _hero(List<Map> all, int pending, int taken, int adherence) {
    return HcHero(
      eyebrow: 'ADHERENCE · SCHEDULED DOSES',
      title: 'Doses',
      subtitle: 'Scheduled medication doses across all patients. Track adherence in real time.',
      icon: Icons.medication_liquid_rounded,
      chips: [
        HcHeroChip(icon: Icons.schedule_rounded, label: '$pending pending'),
        HcHeroChip(icon: Icons.task_alt_rounded, label: '$taken taken'),
        HcHeroChip(icon: Icons.percent_rounded, label: '$adherence% adherence'),
      ],
      trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        TextButton.icon(
          onPressed: () => ref.refresh(_dosesProvider.future),
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
          label: const Text('Refresh', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        TextButton.icon(
          onPressed: () => context.go('/homecare/doses-analysis'),
          icon: const Icon(Icons.show_chart_rounded, color: Colors.white70, size: 18),
          label: const Text('Analysis', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ),
      ]),
    );
  }

  // ── KPI strip ──
  Widget _kpiStrip(int total, int pending, int taken, int missed) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.4,
        children: [
          HcKpi(label: 'Total doses', value: '$total', icon: Icons.medication_liquid_rounded, color: hcTeal),
          HcKpi(label: 'Pending', value: '$pending', icon: Icons.schedule_rounded, color: hcAmber),
          HcKpi(label: 'Taken today', value: '$taken', icon: Icons.task_alt_rounded, color: hcGreen),
          HcKpi(label: 'Missed', value: '$missed', icon: Icons.warning_rounded, color: hcRed),
        ],
      ),
    );
  }

  // ── Filters ──
  Widget _filters(String range, String status) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          TextField(
            onChanged: (v) => ref.read(_doseSearch.notifier).state = v,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded, size: 20),
              hintText: 'Search patient or drug…',
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in _dateRanges)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: range == f.$1,
                    label: Text(f.$2),
                    onSelected: (_) => ref.read(_doseRange.notifier).state = f.$1,
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in _statusFilters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: status == f.$1,
                    label: Text(f.$2),
                    onSelected: (_) => ref.read(_doseStatus.notifier).state = f.$1,
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Grouping ──
  List<Map> _group(List<Map> rows) {
    final map = <String, Map>{};
    for (final d in rows) {
      final dt = DateTime.tryParse(d['scheduled_at']?.toString() ?? '')?.toLocal();
      if (dt == null) continue;
      final key = '${dt.toDateString()}-${dt.hour}';
      final label = DateFormat('EEE, d MMM · HH:00').format(dt);
      map.putIfAbsent(key, () => {'key': key, 'label': label, 'ts': dt.millisecondsSinceEpoch, 'list': <Map>[]});
      (map[key]!['list'] as List).add(d);
    }
    final out = map.values.toList()..sort((a, b) => (a['ts'] as int).compareTo(b['ts'] as int));
    return out;
  }

  Widget _timeGroupHeader(Map g) {
    final list = g['list'] as List;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(children: [
        HcStatusChip(label: g['label'].toString(), color: hcTeal, icon: Icons.schedule_rounded),
        const SizedBox(width: 10),
        const Expanded(child: Divider(height: 1)),
        const SizedBox(width: 10),
        Text('${list.length} dose${list.length == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    );
  }

  // ── Status breakdown ──
  Widget _statusBreakdown(List<Map> all, int adherence, int taken, int missed, int pending, int skipped, int notGiven) {
    final rows = [
      ('Documented', taken, hcGreen),
      ('Pending', pending, hcAmber),
      ('Missed', missed, hcRed),
      ('Skipped', skipped, hcSlate),
      ('Not given', notGiven, hcRed),
    ];
    final total = all.length;
    return HcPanel(
      title: 'Status breakdown',
      subtitle: 'Distribution by current status',
      icon: Icons.donut_large_rounded,
      color: hcPurple,
      child: Column(children: [
        SizedBox(
          height: 120,
          width: 120,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                value: adherence / 100,
                strokeWidth: 12,
                backgroundColor: hcTeal.withValues(alpha: 0.12),
                color: hcTeal,
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$adherence%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: hcTeal)),
              const Text('adherence', style: TextStyle(fontSize: 10)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: r.$3, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(r.$1, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
              Text('${r.$2}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(width: 6),
              SizedBox(
                width: 38,
                child: Text(total > 0 ? '${(r.$2 / total * 100).round()}%' : '0%',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            ]),
          ),
      ]),
    );
  }

  // ── Adherence by patient ──
  Widget _adherenceByPatient(List<Map> all) {
    final map = <String, ({int taken, int total})>{};
    for (final d in all) {
      final k = d['patient_name']?.toString() ?? '—';
      map.putIfAbsent(k, () => (taken: 0, total: 0));
      if (d['status'] == 'taken' || d['status'] == 'missed') {
        map[k] = (taken: map[k]!.taken + (d['status'] == 'taken' ? 1 : 0), total: map[k]!.total + 1);
      }
    }
    final rows = map.entries
        .map((e) => (name: e.key, pct: e.value.total > 0 ? (e.value.taken / e.value.total * 100).round() : 0))
        .toList()
      ..sort((a, b) => a.pct.compareTo(b.pct));
    final top = rows.take(6).toList();
    return HcPanel(
      title: 'Adherence by patient',
      subtitle: 'Bottom performers highlighted',
      icon: Icons.group_rounded,
      color: hcBlue,
      child: top.isEmpty
          ? Text('No data', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
          : Column(children: [
              for (final p in top)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    HcAvatar(name: p.name, size: 34, color: _adherenceColor(p.pct)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                          HcStatusChip(label: '${p.pct}%', color: _adherenceColor(p.pct)),
                        ]),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: p.pct / 100,
                          color: _adherenceColor(p.pct),
                          backgroundColor: _adherenceColor(p.pct).withValues(alpha: 0.12),
                        ),
                      ]),
                    ),
                  ]),
                ),
            ]),
    );
  }

  Color _adherenceColor(int p) {
    if (p >= 85) return hcGreen;
    if (p >= 60) return hcAmber;
    return hcRed;
  }

  // ── Action sheet ──
  void _openAction(Map dose, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DoseActionSheet(
        dose: dose,
        actionType: type,
        onDone: () => ref.invalidate(_dosesProvider),
      ),
    );
  }
}

extension on DateTime {
  String toDateString() => '$year-$month-$day';
}

/// A single dose card — mirrors the web dose card.
class _DoseCard extends StatelessWidget {
  final Map dose;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onAction;
  const _DoseCard({required this.dose, required this.expanded, required this.onToggle, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final status = dose['status']?.toString() ?? '';
    final meta = _statusMeta(status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(color: meta.color, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 18,
              backgroundColor: meta.color.withValues(alpha: 0.14),
              child: Icon(meta.icon, color: meta.color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(dose['medication_name']?.toString() ?? dose['schedule_medication']?.toString() ?? 'Medication',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  ),
                  const SizedBox(width: 6),
                  HcStatusChip(label: meta.display, color: meta.color, icon: meta.icon),
                ]),
                if (dose['dose'] != null) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.medication_rounded, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text('${dose['dose']}${dose['dose_unit'] != null ? ' ${dose['dose_unit']}' : ''}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ]),
                ],
                if (dose['auto_missed'] == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: HcStatusChip(label: 'Auto', color: hcAmber, icon: Icons.smart_toy_outlined),
                  ),
                const SizedBox(height: 4),
                _metaLine(context, Icons.person_outline, dose['patient_name']?.toString()),
                _metaLine(context, Icons.event_outlined, 'Scheduled ${hcDateTime(dose['scheduled_at'])}'),
                if (dose['administered_at'] != null)
                  _metaLine(context, Icons.check_circle_outline, 'Given ${hcDateTime(dose['administered_at'])}', color: hcGreen),
                if ((dose['administered_by_name'] ?? '').toString().isNotEmpty)
                  _metaLine(context, Icons.verified_user_outlined, 'by ${dose['administered_by_name']}'
                      '${dose['administered_by_role'] != null ? ' (${dose['administered_by_role']})' : ''}'),
                if ((dose['reason'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.message_outlined, size: 13, color: hcAmber),
                      const SizedBox(width: 4),
                      Expanded(child: Text('Reason: ${dose['reason']}', style: const TextStyle(fontSize: 11.5))),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (status == 'pending' || status == 'overdue') ...[
              TextButton.icon(
                onPressed: () => onAction('document'),
                icon: const Icon(Icons.task_alt_rounded, size: 16),
                label: const Text('Document'),
                style: TextButton.styleFrom(foregroundColor: hcGreen),
              ),
              TextButton.icon(
                onPressed: () => onAction('skip'),
                icon: const Icon(Icons.skip_next_rounded, size: 16),
                label: const Text('Skip'),
                style: TextButton.styleFrom(foregroundColor: hcAmber),
              ),
              TextButton.icon(
                onPressed: () => onAction('not_given'),
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Not given'),
                style: TextButton.styleFrom(foregroundColor: hcRed),
              ),
            ],
            TextButton.icon(
              onPressed: () => onAction('edit'),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
              style: TextButton.styleFrom(foregroundColor: hcTeal),
            ),
            IconButton(
              tooltip: expanded ? 'Hide audit' : 'Audit trail',
              onPressed: onToggle,
              icon: Icon(expanded ? Icons.expand_less_rounded : Icons.history_rounded, size: 18),
            ),
          ]),
        ),
        if (expanded) _auditTrail(context, dose),
      ]),
    );
  }

  Widget _metaLine(BuildContext context, IconData icon, String? text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(children: [
        Icon(icon, size: 13, color: color ?? Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Expanded(child: Text(text ?? '—', style: TextStyle(fontSize: 11.5, color: color))),
      ]),
    );
  }

  Widget _auditTrail(BuildContext context, Map d) {
    final logs = (d['audit_log'] as List?)?.cast<Map>() ?? const [];
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.history_rounded, size: 12),
          SizedBox(width: 5),
          Text('AUDIT TRAIL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        if (logs.isEmpty)
          const Text('No history yet.', style: TextStyle(fontSize: 11.5))
        else
          for (var i = 0; i < logs.length; i++)
            _auditItem(context, logs[i], i == logs.length - 1),
      ]),
    );
  }

  Widget _auditItem(BuildContext context, Map log, bool last) {
    final action = log['action']?.toString() ?? '';
    final color = _auditColor(action);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Column(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        if (!last) Container(width: 2, height: 26, color: color.withValues(alpha: 0.3)),
      ]),
      const SizedBox(width: 8),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(log['by_name']?.toString().isNotEmpty == true ? log['by_name'].toString() : 'system',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              HcStatusChip(label: action, color: color),
              if (log['status_to'] != null) ...[
                const SizedBox(width: 4),
                Text('→ ${_statusMeta(log['status_to'].toString()).display}',
                    style: TextStyle(fontSize: 11, color: _statusMeta(log['status_to'].toString()).color, fontWeight: FontWeight.w600)),
              ],
            ]),
            Text(hcDateTime(log['at']),
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            if (log['dose_to'] != null)
              Text('dose ${log['dose_from'] ?? '—'} → ${log['dose_to']}',
                  style: const TextStyle(fontSize: 11)),
            if (log['reason'] != null)
              Text(log['reason'].toString(), style: const TextStyle(fontSize: 11)),
          ]),
        ),
      ),
    ]);
  }

  Color _auditColor(String action) => switch (action) {
        'document' => hcGreen,
        'skip' => hcAmber,
        'not_given' => hcRed,
        'mark_missed' => hcRed,
        'auto_missed' => hcAmber,
        'edit_assessment' => hcTeal,
        _ => hcSlate,
      };
}

