import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/api.dart';
import 'hc_common.dart';

final _escalationsProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/escalations/', params: {'page_size': 200});
});

final _escFilter = StateProvider.autoDispose((_) => 'open');

/// Clinical escalations: triage, acknowledge and resolve.
class HomecareEscalationsScreen extends ConsumerWidget {
  const HomecareEscalationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final escalations = ref.watch(_escalationsProvider);
    final filter = ref.watch(_escFilter);

    return HcAsyncBody(
      value: escalations,
      onRefresh: () async => ref.refresh(_escalationsProvider.future),
      builder: (list) {
        final all = list.cast<Map>().toList()
          ..sort((a, b) => (b['triggered_at'] ?? '')
              .toString()
              .compareTo((a['triggered_at'] ?? '').toString()));
        final filtered = filter == 'all'
            ? all
            : all.where((e) => e['status'] == filter).toList();
        final open = all.where((e) => e['status'] == 'open').length;
        final critical = all
            .where((e) =>
                e['severity'] == 'critical' && e['status'] != 'resolved')
            .length;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: 'CLINICAL SAFETY',
              title: 'Escalations',
              subtitle: 'Patients flagged for clinical attention',
              icon: Icons.notification_important_rounded,
              gradient: const [
                Color(0xFF7F1D1D),
                Color(0xFFB91C1C),
                Color(0xFFDC2626)
              ],
              chips: [
                HcHeroChip(icon: Icons.error_rounded, label: '$open open'),
                HcHeroChip(
                    icon: Icons.warning_amber_rounded,
                    label: '$critical critical'),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                for (final f in const [
                  ('open', 'Open'),
                  ('acknowledged', 'Acknowledged'),
                  ('resolved', 'Resolved'),
                  ('all', 'All'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: filter == f.$1,
                      label: Text(f.$2),
                      onSelected: (_) =>
                          ref.read(_escFilter.notifier).state = f.$1,
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('Nothing here. All clear!')),
              )
            else
              ...filtered.map((e) => _EscalationCard(
                    escalation: e,
                    onChanged: () => ref.invalidate(_escalationsProvider),
                  )),
          ],
        );
      },
    );
  }
}

class _EscalationCard extends ConsumerWidget {
  final Map escalation;
  final VoidCallback onChanged;
  const _EscalationCard({required this.escalation, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = escalation;
    final severity = e['severity']?.toString();
    final status = e['status']?.toString();
    final sevColor = hcSeverityColor(severity);
    final triggered =
        DateTime.tryParse((e['triggered_at'] ?? '').toString())?.toLocal();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            HcAvatar(
                name: e['patient_name']?.toString(),
                color: sevColor,
                size: 42),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e['patient_name']?.toString() ?? '—',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13.5)),
                    Text(
                        triggered != null
                            ? timeago.format(triggered)
                            : '—',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ]),
            ),
            HcStatusChip(
                label: hcLabel(severity),
                color: sevColor,
                icon: Icons.priority_high_rounded),
            const SizedBox(width: 6),
            HcStatusChip(
                label: hcLabel(status),
                color: status == 'resolved'
                    ? hcGreen
                    : status == 'acknowledged'
                        ? hcAmber
                        : hcRed),
          ]),
          const SizedBox(height: 8),
          Text(e['reason']?.toString() ?? '—',
              style: const TextStyle(fontSize: 13)),
          if ((e['detail'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(e['detail'].toString(),
                  style: TextStyle(
                      fontSize: 12,
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          if ((e['acknowledged_by_name'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Acknowledged by ${e['acknowledged_by_name']}',
                  style: const TextStyle(fontSize: 11, color: hcAmber)),
            ),
          if ((e['resolution_notes'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Resolution: ${e['resolution_notes']}',
                  style: const TextStyle(fontSize: 11, color: hcGreen)),
            ),
          if (status != 'resolved')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                if (status == 'open')
                  OutlinedButton.icon(
                    onPressed: () => _acknowledge(context, ref),
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: const Text('Acknowledge'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: hcAmber,
                        visualDensity: VisualDensity.compact),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _openResolve(context, ref),
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text('Resolve'),
                  style: FilledButton.styleFrom(
                      backgroundColor: hcGreen,
                      visualDensity: VisualDensity.compact),
                ),
              ]),
            ),
        ]),
      ),
    );
  }

  Future<void> _acknowledge(BuildContext context, WidgetRef ref) async {
    try {
      final dio = ref.read(dioProvider);
      await dio
          .post('/homecare/escalations/${escalation['id']}/acknowledge/');
      onChanged();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not acknowledge.')));
      }
    }
  }

  void _openResolve(BuildContext context, WidgetRef ref) {
    final notes = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resolve escalation',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Resolution notes',
                  hintText: 'What action was taken?'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: hcGreen),
                onPressed: () async {
                  try {
                    final dio = ref.read(dioProvider);
                    await dio.post(
                        '/homecare/escalations/${escalation['id']}/resolve/',
                        data: {'notes': notes.text.trim()});
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                    onChanged();
                  } catch (_) {
                    if (sheetCtx.mounted) {
                      ScaffoldMessenger.of(sheetCtx).showSnackBar(
                          const SnackBar(
                              content: Text('Could not resolve.')));
                    }
                  }
                },
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text('Resolve'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
