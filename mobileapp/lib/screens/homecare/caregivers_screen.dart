import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'hc_common.dart';

final caregiversProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/caregivers/', params: {'page_size': 200});
});

final _cgSearch = StateProvider.autoDispose((_) => '');
final _cgFilter = StateProvider.autoDispose((_) => 'all');

/// Caregiver workforce directory.
class HomecareCaregiversScreen extends ConsumerWidget {
  const HomecareCaregiversScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caregivers = ref.watch(caregiversProvider);
    final query = ref.watch(_cgSearch);
    final filter = ref.watch(_cgFilter);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'enroll-caregiver',
        onPressed: () => context.go('/homecare/caregivers/new'),
        backgroundColor: hcBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add'),
      ),
      body: HcAsyncBody(
        value: caregivers,
        onRefresh: () async => ref.refresh(caregiversProvider.future),
        builder: (list) {
          var filtered = list.cast<Map>().where((c) {
            switch (filter) {
              case 'available':
                if (c['is_available'] != true) return false;
              case 'off':
                if (c['is_available'] == true) return false;
            }
            if (query.isEmpty) return true;
            final q = query.toLowerCase();
            return [
              c['user']?['full_name'],
              c['user']?['email'],
              c['license_number'],
              c['category_label'],
              (c['specialties'] as List?)?.join(' '),
            ].any((v) => (v ?? '').toString().toLowerCase().contains(q));
          }).toList();

          final available =
              list.cast<Map>().where((c) => c['is_available'] == true).length;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              HcHero(
                eyebrow: 'WORKFORCE',
                title: 'Caregivers',
                subtitle: 'Your clinical field team',
                icon: Icons.medical_services_rounded,
                gradient: const [
                  Color(0xFF0E7490),
                  Color(0xFF0891B2),
                  Color(0xFF06B6D4)
                ],
                chips: [
                  HcHeroChip(
                      icon: Icons.groups_rounded,
                      label: '${list.length} total'),
                  HcHeroChip(
                      icon: Icons.check_circle_rounded,
                      label: '$available available'),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (v) => ref.read(_cgSearch.notifier).state = v,
                  decoration: InputDecoration(
                    hintText: 'Search name, license, specialty…',
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
                child: Row(children: [
                  for (final f in const [
                    ('all', 'All'),
                    ('available', 'Available'),
                    ('off', 'Off duty'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: filter == f.$1,
                        label: Text(f.$2),
                        onSelected: (_) =>
                            ref.read(_cgFilter.notifier).state = f.$1,
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: Text('No caregivers match.')),
                )
              else
                ...filtered.asMap().entries.map((e) {
                  final c = e.value;
                  final name = (c['user']?['full_name'] ??
                          c['user']?['email'] ??
                          '—')
                      .toString();
                  final available = c['is_available'] == true;
                  return Card(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: ListTile(
                      onTap: () =>
                          context.go('/homecare/caregivers/${c['id']}'),
                      leading: HcAvatar(
                          name: name,
                          size: 44,
                          color: available ? hcTeal : hcSlate),
                      title: Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${c['category_label'] ?? 'Caregiver'}'
                              '${(c['license_number'] ?? '').toString().isNotEmpty ? ' · ${c['license_number']}' : ''}',
                              style: const TextStyle(fontSize: 11.5)),
                          Row(children: [
                            const Icon(Icons.star_rounded,
                                size: 13, color: hcAmber),
                            Text(
                                ' ${c['rating'] ?? 0} · ${c['total_visits'] ?? 0} visits · ${c['active_patients_count'] ?? 0} patients',
                                style: const TextStyle(fontSize: 11)),
                          ]),
                        ],
                      ),
                      trailing: HcStatusChip(
                        label: available ? 'AVAILABLE' : 'OFF DUTY',
                        color: available ? hcGreen : hcSlate,
                        icon: available
                            ? Icons.check_circle_rounded
                            : Icons.pause_circle_rounded,
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
