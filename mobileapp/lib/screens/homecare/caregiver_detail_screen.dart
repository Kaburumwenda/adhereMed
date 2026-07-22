import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import 'hc_common.dart';

final _caregiverProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, int>((ref, id) async {
  final dio = ref.read(dioProvider);
  final results = await Future.wait([
    dio.get('/homecare/caregivers/$id/'),
    dio.get('/homecare/caregivers/$id/assigned-patients/'),
    dio.get('/homecare/schedules/', queryParameters: {
      'caregiver': id,
      'page_size': 10,
      'ordering': '-start_at'
    }),
  ]);
  final schedData = results[2].data;
  return {
    'caregiver': results[0].data as Map<String, dynamic>,
    'patients': (results[1].data as List?) ?? [],
    'schedules': schedData is List
        ? schedData
        : ((schedData?['results'] as List?) ?? []),
  };
});

/// Caregiver profile: identity, workload, availability toggle,
/// assigned patients and recent shifts.
class HomecareCaregiverDetailScreen extends ConsumerWidget {
  final int id;
  const HomecareCaregiverDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_caregiverProvider(id));

    return HcAsyncBody(
      value: data,
      onRefresh: () async => ref.refresh(_caregiverProvider(id).future),
      builder: (d) {
        final c = d['caregiver'] as Map<String, dynamic>;
        final patients = (d['patients'] as List?) ?? [];
        final schedules = (d['schedules'] as List?) ?? [];
        final name =
            (c['user']?['full_name'] ?? c['user']?['email'] ?? '—').toString();
        final available = c['is_available'] == true;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: (c['category_label'] ?? 'CAREGIVER')
                  .toString()
                  .toUpperCase(),
              title: name,
              subtitle: (c['user']?['email'] ?? '').toString(),
              icon: Icons.medical_services_rounded,
              gradient: const [
                Color(0xFF0E7490),
                Color(0xFF0891B2),
                Color(0xFF06B6D4)
              ],
              chips: [
                HcHeroChip(
                    icon: Icons.star_rounded, label: '${c['rating'] ?? 0}'),
                HcHeroChip(
                    icon: Icons.verified_rounded,
                    label: '${c['total_visits'] ?? 0} visits'),
                HcHeroChip(
                    icon: available
                        ? Icons.check_circle_rounded
                        : Icons.pause_circle_rounded,
                    label: available ? 'Available' : 'Off duty'),
              ],
            ),
            HcPanel(
              title: 'Availability',
              icon: Icons.toggle_on_rounded,
              color: hcTeal,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: available,
                title: Text(available
                    ? 'Accepting new visits'
                    : 'Marked as off duty'),
                onChanged: (_) async {
                  try {
                    final dio = ref.read(dioProvider);
                    await dio.post(
                        '/homecare/caregivers/$id/toggle_availability/');
                    ref.invalidate(_caregiverProvider(id));
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Could not update availability.')));
                    }
                  }
                },
              ),
            ),
            HcPanel(
              title: 'Profile',
              icon: Icons.badge_rounded,
              color: hcBlue,
              child: Column(children: [
                HcInfoRow(
                    label: 'Category',
                    value: (c['category_label'] ?? '').toString(),
                    icon: Icons.workspaces_rounded),
                HcInfoRow(
                    label: 'License',
                    value: (c['license_number'] ?? '').toString(),
                    icon: Icons.verified_user_rounded),
                HcInfoRow(
                    label: 'Specialties',
                    value: ((c['specialties'] as List?) ?? []).join(', '),
                    icon: Icons.star_border_rounded),
                HcInfoRow(
                    label: 'Hourly rate',
                    value: hcMoney(c['hourly_rate']),
                    icon: Icons.payments_rounded),
                HcInfoRow(
                    label: 'Hired',
                    value: hcDate(c['hire_date']),
                    icon: Icons.event_rounded),
                HcInfoRow(
                    label: 'Status',
                    value: hcLabel(c['employment_status']?.toString()),
                    icon: Icons.work_history_rounded),
              ]),
            ),
            HcPanel(
              title: 'Assigned patients',
              subtitle: '${patients.length} under care',
              icon: Icons.people_alt_rounded,
              color: hcTeal,
              child: patients.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: Text('No patients assigned.')),
                    )
                  : Column(
                      children: patients.map<Widget>((p) {
                        final m = p as Map;
                        final risk = m['risk_level']?.toString() ?? 'low';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onTap: () =>
                              context.go('/homecare/patients/${m['id']}'),
                          leading: HcAvatar(
                              name: m['patient_name']?.toString(),
                              size: 38,
                              color: hcRiskColor(risk)),
                          title: Text(m['patient_name']?.toString() ?? '—',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          subtitle: Text(
                              (m['medical_record_number'] ?? '').toString(),
                              style: const TextStyle(fontSize: 11)),
                          trailing: HcStatusChip(
                              label: risk.toUpperCase(),
                              color: hcRiskColor(risk)),
                        );
                      }).toList(),
                    ),
            ),
            HcPanel(
              title: 'Recent shifts',
              icon: Icons.event_note_rounded,
              color: hcAmber,
              child: schedules.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: Text('No shifts recorded.')),
                    )
                  : Column(
                      children: schedules.map<Widget>((s) {
                        final m = s as Map;
                        final status = m['status']?.toString();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(Icons.schedule_rounded,
                              color: hcVisitStatusColor(status), size: 20),
                          title: Text(m['patient_name']?.toString() ?? '—',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          subtitle: Text(
                              '${hcDate(m['start_at'])} · ${hcTimeRange(m['start_at'], m['end_at'])}',
                              style: const TextStyle(fontSize: 11)),
                          trailing: HcStatusChip(
                              label: hcLabel(status),
                              color: hcVisitStatusColor(status)),
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
