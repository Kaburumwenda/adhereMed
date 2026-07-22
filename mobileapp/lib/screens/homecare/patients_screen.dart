import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import 'hc_common.dart';

final _patientsProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/patients/', params: {'page_size': 200});
});

final _patientSearch = StateProvider.autoDispose((_) => '');
final _patientFilter = StateProvider.autoDispose((_) => 'active');

/// Homecare patients directory with search + risk/state filters.
class HomecarePatientsScreen extends ConsumerWidget {
  const HomecarePatientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(_patientsProvider);
    final query = ref.watch(_patientSearch);
    final filter = ref.watch(_patientFilter);
    final isAdmin = ref.watch(authProvider).user?.role != 'caregiver';

    return Scaffold(
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              heroTag: 'enroll-patient',
              onPressed: () => context.go('/homecare/patients/new'),
              backgroundColor: hcTeal,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Enroll'),
            )
          : null,
      body: HcAsyncBody(
        value: patients,
        onRefresh: () async => ref.refresh(_patientsProvider.future),
        builder: (list) {
          var filtered = list.cast<Map>().where((p) {
            switch (filter) {
              case 'active':
                if (p['is_active'] != true) return false;
              case 'high':
                if (p['risk_level'] != 'high' || p['is_active'] != true) {
                  return false;
                }
              case 'inactive':
                if (p['is_active'] == true) return false;
            }
            if (query.isEmpty) return true;
            final q = query.toLowerCase();
            return [
              p['patient_name'],
              p['medical_record_number'],
              p['adheremed_patient_id'],
              p['assigned_caregiver_name'],
              p['primary_diagnosis'],
            ].any((v) => (v ?? '').toString().toLowerCase().contains(q));
          }).toList();

          final active =
              list.cast<Map>().where((p) => p['is_active'] == true).length;
          final high = list
              .cast<Map>()
              .where((p) =>
                  p['risk_level'] == 'high' && p['is_active'] == true)
              .length;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              HcHero(
                eyebrow: 'CARE OPERATIONS',
                title: 'Patients',
                subtitle: 'Everyone enrolled in your homecare programme',
                icon: Icons.people_alt_rounded,
                chips: [
                  HcHeroChip(
                      icon: Icons.favorite_rounded, label: '$active active'),
                  HcHeroChip(
                      icon: Icons.warning_amber_rounded,
                      label: '$high high risk'),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) =>
                      ref.read(_patientSearch.notifier).state = v,
                  decoration: InputDecoration(
                    hintText: 'Search name, MRN, caregiver…',
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
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final f in const [
                      ('active', 'Active'),
                      ('high', 'High risk'),
                      ('all', 'All'),
                      ('inactive', 'Discharged'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          selected: filter == f.$1,
                          label: Text(f.$2),
                          onSelected: (_) =>
                              ref.read(_patientFilter.notifier).state = f.$1,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('No patients match.')),
                )
              else
                ...filtered.asMap().entries.map((e) {
                  final p = e.value;
                  final risk = p['risk_level']?.toString() ?? 'low';
                  return Card(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: ListTile(
                      onTap: () =>
                          context.go('/homecare/patients/${p['id']}'),
                      leading: HcAvatar(
                          name: p['patient_name']?.toString(),
                          color: hcRiskColor(risk),
                          size: 44),
                      title: Text(p['patient_name']?.toString() ?? '—',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${p['medical_record_number'] ?? ''}'
                              '${(p['age'] != null) ? ' · ${p['age']} yrs' : ''}'
                              '${(p['gender'] ?? '').toString().isNotEmpty ? ' · ${hcLabel(p['gender'].toString())}' : ''}',
                              style: const TextStyle(fontSize: 11.5)),
                          if ((p['assigned_caregiver_name'] ?? '')
                              .toString()
                              .isNotEmpty)
                            Text('CG: ${p['assigned_caregiver_name']}',
                                style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          HcStatusChip(
                              label: risk.toUpperCase(),
                              color: hcRiskColor(risk)),
                          if ((p['open_escalations'] ?? 0) != 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: HcStatusChip(
                                  label: '${p['open_escalations']} alerts',
                                  color: hcRed,
                                  icon: Icons.warning_amber_rounded),
                            ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(
                      duration: 250.ms, delay: (25 * (e.key % 12)).ms);
                }),
            ],
          );
        },
      ),
    );
  }
}
