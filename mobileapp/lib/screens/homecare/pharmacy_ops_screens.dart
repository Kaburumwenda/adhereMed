import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'hc_common.dart';

// ═════════════════ APPOINTMENTS ═════════════════
final _appointmentsProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/appointments/', params: {'page_size': 200});
});

class HomecareAppointmentsScreen extends ConsumerWidget {
  const HomecareAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(_appointmentsProvider);
    return HcAsyncBody(
      value: appointments,
      onRefresh: () async => ref.refresh(_appointmentsProvider.future),
      builder: (list) {
        final rows = list.cast<Map>().toList()
          ..sort((a, b) => (b['scheduled_at'] ?? '')
              .toString()
              .compareTo((a['scheduled_at'] ?? '').toString()));
        final upcoming = rows.where((a) {
          final at =
              DateTime.tryParse((a['scheduled_at'] ?? '').toString());
          return at != null &&
              at.isAfter(DateTime.now()) &&
              !['cancelled', 'completed'].contains(a['status']);
        }).length;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: 'SCHEDULING',
              title: 'Appointments',
              subtitle: 'In-home visits, teleconsults & clinic bookings',
              icon: Icons.event_available_rounded,
              chips: [
                HcHeroChip(
                    icon: Icons.upcoming_rounded, label: '$upcoming upcoming'),
                HcHeroChip(
                    icon: Icons.all_inbox_rounded,
                    label: '${rows.length} total'),
              ],
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('No appointments.')),
              )
            else
              ...rows.take(60).map((a) {
                final status = (a['status'] ?? '').toString();
                final type = (a['appointment_type'] ?? '').toString();
                return Card(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: ListTile(
                    leading: Icon(
                        type == 'teleconsult'
                            ? Icons.videocam_rounded
                            : type == 'clinic'
                                ? Icons.local_hospital_rounded
                                : Icons.home_rounded,
                        color: hcBlue),
                    title: Text(a['patient_name']?.toString() ?? '—',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13.5)),
                    subtitle: Text(
                        '${hcLabel(type)} · ${hcDateTime(a['scheduled_at'])}'
                        '${(a['doctor_name'] ?? '').toString().isNotEmpty ? ' · Dr ${a['doctor_name']}' : ''}',
                        style: const TextStyle(fontSize: 11.5)),
                    trailing: HcStatusChip(
                        label: hcLabel(status),
                        color: switch (status) {
                          'completed' => hcGreen,
                          'confirmed' => hcTeal,
                          'cancelled' || 'no_show' => hcRed,
                          _ => hcBlue,
                        }),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

// ═════════════════ PHARMACY STOCK ALERTS ═════════════════
final _stockAlertsProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/stock-alerts/', params: {'page_size': 200});
});

class HomecareStockAlertsScreen extends ConsumerWidget {
  const HomecareStockAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(_stockAlertsProvider);
    return HcAsyncBody(
      value: alerts,
      onRefresh: () async => ref.refresh(_stockAlertsProvider.future),
      builder: (list) {
        final rows = list.cast<Map>();
        final open = rows.where((a) => a['resolved'] != true).length;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: 'MEDICATION SUPPLY',
              title: 'Stock alerts',
              subtitle: 'Pharmacy availability for patient medications',
              icon: Icons.inventory_rounded,
              gradient: const [
                Color(0xFF92400E),
                Color(0xFFD97706),
                Color(0xFFF59E0B)
              ],
              chips: [
                HcHeroChip(icon: Icons.error_rounded, label: '$open open'),
              ],
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('No stock alerts.')),
              )
            else
              ...rows.map((a) {
                final status = (a['stock_status'] ?? '').toString();
                final resolved = a['resolved'] == true;
                return Card(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: ListTile(
                    leading: Icon(Icons.medication_rounded,
                        color: status == 'out'
                            ? hcRed
                            : status == 'low'
                                ? hcAmber
                                : hcGreen),
                    title: Text(a['medication_name']?.toString() ?? '—',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13.5)),
                    subtitle: Text(
                        '${a['patient_name'] ?? ''}'
                        '${(a['pharmacy_name'] ?? '').toString().isNotEmpty ? ' · ${a['pharmacy_name']}' : ''}',
                        style: const TextStyle(fontSize: 11.5)),
                    trailing: HcStatusChip(
                        label: resolved
                            ? 'RESOLVED'
                            : status == 'out'
                                ? 'OUT OF STOCK'
                                : status == 'low'
                                    ? 'LOW STOCK'
                                    : hcLabel(status),
                        color: resolved
                            ? hcGreen
                            : status == 'out'
                                ? hcRed
                                : hcAmber),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

// ═════════════════ DRUG INTERACTIONS & SAFETY ═════════════════
final _interactionsProvider = FutureProvider.autoDispose((ref) async {
  final results = await Future.wait([
    hcFetchAll(ref, '/homecare/drug-interactions/', params: {'page_size': 200}),
    hcFetchAll(ref, '/homecare/safety-alerts/', params: {'page_size': 200}),
  ]);
  return {'interactions': results[0], 'alerts': results[1]};
});

class HomecareDrugSafetyScreen extends ConsumerWidget {
  const HomecareDrugSafetyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_interactionsProvider);
    return HcAsyncBody(
      value: data,
      onRefresh: () async => ref.refresh(_interactionsProvider.future),
      builder: (d) {
        final interactions = (d['interactions'] as List).cast<Map>();
        final alerts = (d['alerts'] as List).cast<Map>();
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: 'MEDICATION SAFETY',
              title: 'Drug safety',
              subtitle: 'Interaction rules & prescription safety alerts',
              icon: Icons.gpp_maybe_rounded,
              gradient: const [
                Color(0xFF7F1D1D),
                Color(0xFFB91C1C),
                Color(0xFFDC2626)
              ],
              chips: [
                HcHeroChip(
                    icon: Icons.rule_rounded,
                    label: '${interactions.length} rules'),
                HcHeroChip(
                    icon: Icons.warning_amber_rounded,
                    label: '${alerts.length} alerts'),
              ],
            ),
            HcPanel(
              title: 'Safety alerts',
              subtitle: 'Triggered on prescriptions',
              icon: Icons.warning_amber_rounded,
              color: hcRed,
              child: alerts.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: Text('No safety alerts.')),
                    )
                  : Column(
                      children: alerts.take(20).map<Widget>((a) {
                        final sev = (a['severity'] ?? '').toString();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(Icons.error_rounded,
                              color: hcSeverityColor(sev), size: 20),
                          title: Text(
                              (a['title'] ?? a['message'] ?? '—')
                                  .toString(),
                              maxLines: 2,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5)),
                          subtitle: Text(
                              '${a['patient_name'] ?? ''} · ${hcDate(a['created_at'])}',
                              style: const TextStyle(fontSize: 11)),
                          trailing: HcStatusChip(
                              label: hcLabel(sev),
                              color: hcSeverityColor(sev)),
                        );
                      }).toList(),
                    ),
            ),
            HcPanel(
              title: 'Interaction rules',
              icon: Icons.rule_rounded,
              color: hcPurple,
              child: interactions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: Text('No interaction rules.')),
                    )
                  : Column(
                      children: interactions.take(30).map<Widget>((r) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.sync_alt_rounded,
                              color: hcPurple, size: 20),
                          title: Text(
                              '${r['drug_a'] ?? r['medication_a'] ?? '—'} ↔ ${r['drug_b'] ?? r['medication_b'] ?? '—'}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5)),
                          subtitle: Text(
                              (r['description'] ?? r['effect'] ?? '')
                                  .toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11)),
                          trailing: HcStatusChip(
                              label: hcLabel(
                                  (r['severity'] ?? '').toString()),
                              color: hcSeverityColor(
                                  (r['severity'] ?? '').toString())),
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ═════════════════ CARE PATHWAYS ═════════════════
final _pathwaysProvider = FutureProvider.autoDispose((ref) async {
  final results = await Future.wait([
    hcFetchAll(ref, '/homecare/care-pathways/', params: {'page_size': 100}),
    hcFetchAll(ref, '/homecare/pathway-enrollments/',
        params: {'page_size': 200}),
  ]);
  return {'pathways': results[0], 'enrollments': results[1]};
});

class HomecareCarePathwaysScreen extends ConsumerWidget {
  const HomecareCarePathwaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_pathwaysProvider);
    return HcAsyncBody(
      value: data,
      onRefresh: () async => ref.refresh(_pathwaysProvider.future),
      builder: (d) {
        final pathways = (d['pathways'] as List).cast<Map>();
        final enrollments = (d['enrollments'] as List).cast<Map>();
        final byPathway = <dynamic, int>{};
        for (final e in enrollments) {
          byPathway[e['pathway']] = (byPathway[e['pathway']] ?? 0) + 1;
        }
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: 'STANDARDISED CARE',
              title: 'Care pathways',
              subtitle: 'Condition-based care programmes',
              icon: Icons.route_rounded,
              gradient: const [
                Color(0xFF065F46),
                Color(0xFF059669),
                Color(0xFF10B981)
              ],
              chips: [
                HcHeroChip(
                    icon: Icons.route_rounded,
                    label: '${pathways.length} pathways'),
                HcHeroChip(
                    icon: Icons.people_rounded,
                    label: '${enrollments.length} enrolled'),
              ],
            ),
            if (pathways.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('No care pathways defined.')),
              )
            else
              ...pathways.map((p) => Card(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: ListTile(
                      leading:
                          const Icon(Icons.route_rounded, color: hcGreen),
                      title: Text(p['name']?.toString() ?? '—',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13.5)),
                      subtitle: Text(
                          (p['description'] ?? p['condition'] ?? '')
                              .toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5)),
                      trailing: HcStatusChip(
                          label: '${byPathway[p['id']] ?? 0} enrolled',
                          color: hcGreen),
                    ),
                  )),
          ],
        );
      },
    );
  }
}
