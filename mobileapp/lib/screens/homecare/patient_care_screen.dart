import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import 'hc_common.dart';

final _pcPatientsProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/patients/',
      params: {'is_active': 'true', 'page_size': 200});
});

final _pcPlansProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/care-plans/', params: {'page_size': 200});
});

final _pcSearch = StateProvider.autoDispose((_) => '');

/// Patient Care Management: active patients with (admin) plan status.
/// Tapping opens the mobile command centre.
class HomecarePatientCareScreen extends ConsumerWidget {
  const HomecarePatientCareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(_pcPatientsProvider);
    final isAdmin = ref.watch(authProvider).user?.role != 'caregiver';
    final plans = isAdmin ? ref.watch(_pcPlansProvider) : null;
    final query = ref.watch(_pcSearch);

    return HcAsyncBody(
      value: patients,
      onRefresh: () async {
        if (isAdmin) ref.invalidate(_pcPlansProvider);
        return ref.refresh(_pcPatientsProvider.future);
      },
      builder: (list) {
        final planByPatient = <int, Map>{};
        if (isAdmin) {
          for (final pl
              in (plans?.valueOrNull ?? const []).cast<Map>()) {
            if (pl['is_active'] == true) {
              planByPatient[pl['patient'] as int] = pl;
            }
          }
        }

        var rows = list.cast<Map>().toList();
        if (query.isNotEmpty) {
          final q = query.toLowerCase();
          rows = rows
              .where((p) => [
                    p['patient_name'],
                    p['medical_record_number'],
                    p['assigned_caregiver_name'],
                  ].any((v) =>
                      (v ?? '').toString().toLowerCase().contains(q)))
              .toList();
        }

        final onPlan = isAdmin
            ? rows.where((p) => planByPatient.containsKey(p['id'])).length
            : 0;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: isAdmin ? 'CARE & BILLING' : 'MY PATIENTS',
              title: 'Patient Care',
              subtitle: isAdmin
                  ? 'Plans, supplies, medications and billing per patient'
                  : 'Clinical care management for your assigned patients',
              icon: Icons.volunteer_activism_rounded,
              chips: [
                HcHeroChip(
                    icon: Icons.people_rounded,
                    label: '${rows.length} active'),
                if (isAdmin)
                  HcHeroChip(
                      icon: Icons.event_available_rounded,
                      label: '$onPlan on a plan'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => ref.read(_pcSearch.notifier).state = v,
                decoration: InputDecoration(
                  hintText: 'Search patient…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('No active patients.')),
              )
            else
              ...rows.map((p) {
                final plan = planByPatient[p['id']];
                final risk = p['risk_level']?.toString() ?? 'low';
                return Card(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: ListTile(
                    onTap: () =>
                        context.go('/homecare/patient-care/${p['id']}'),
                    leading: HcAvatar(
                        name: p['patient_name']?.toString(),
                        size: 44,
                        color: hcRiskColor(risk)),
                    title: Text(p['patient_name']?.toString() ?? '—',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${p['medical_record_number'] ?? ''}'
                            '${(p['assigned_caregiver_name'] ?? '').toString().isNotEmpty ? ' · CG ${p['assigned_caregiver_name']}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5)),
                        if (isAdmin)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: plan != null
                                ? HcStatusChip(
                                    label:
                                        '${plan['plan_type_label'] ?? 'Plan'} · ${hcMoney(plan['rate'], currency: (plan['currency'] ?? 'KSh').toString())}',
                                    color: hcTeal,
                                    icon: Icons.event_available_rounded)
                                : const HcStatusChip(
                                    label: 'No payment plan',
                                    color: hcAmber,
                                    icon: Icons.warning_amber_rounded),
                          ),
                      ],
                    ),
                    trailing:
                        const Icon(Icons.chevron_right_rounded, size: 22),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
