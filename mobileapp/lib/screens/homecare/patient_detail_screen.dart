import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api.dart';
import 'hc_common.dart';

final _patientProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, id) async {
  final dio = ref.read(dioProvider);
  final results = await Future.wait([
    dio.get('/homecare/patients/$id/'),
    dio.get('/homecare/vitals/', queryParameters: {'patient': id}),
    dio.get('/homecare/escalations/',
        queryParameters: {'patient': id, 'page_size': 5}),
  ]);
  final vitalsData = results[1].data;
  final escData = results[2].data;
  return {
    'patient': results[0].data as Map<String, dynamic>,
    'vitals': vitalsData is List
        ? vitalsData
        : ((vitalsData?['results'] as List?) ?? []),
    'escalations': escData is List
        ? escData
        : ((escData?['results'] as List?) ?? []),
  };
});

/// Patient profile: identity, care team, clinical info, recent vitals,
/// emergency contacts and quick actions (directions / call).
class HomecarePatientDetailScreen extends ConsumerWidget {
  final int id;
  const HomecarePatientDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_patientProvider(id));

    return HcAsyncBody(
      value: data,
      onRefresh: () async => ref.refresh(_patientProvider(id).future),
      builder: (d) {
        final p = d['patient'] as Map<String, dynamic>;
        final vitals = (d['vitals'] as List?) ?? [];
        final escalations = (d['escalations'] as List?) ?? [];
        final risk = p['risk_level']?.toString() ?? 'low';
        final contacts = (p['emergency_contacts'] as List?) ?? [];
        final latest = vitals.isNotEmpty ? vitals.first as Map : null;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: (p['is_active'] == true) ? 'ACTIVE PATIENT' : 'DISCHARGED',
              title: p['patient_name']?.toString() ?? 'Patient',
              subtitle:
                  '${p['medical_record_number'] ?? ''}${p['age'] != null ? ' · ${p['age']} yrs' : ''}${(p['gender'] ?? '').toString().isNotEmpty ? ' · ${hcLabel(p['gender'].toString())}' : ''}',
              icon: Icons.person_rounded,
              gradient: risk == 'high'
                  ? const [Color(0xFF7F1D1D), Color(0xFFB91C1C), Color(0xFFDC2626)]
                  : risk == 'medium'
                      ? const [Color(0xFF92400E), Color(0xFFD97706), Color(0xFFF59E0B)]
                      : null,
              chips: [
                HcHeroChip(
                    icon: Icons.shield_rounded,
                    label: '${risk.toUpperCase()} RISK'),
                if (latest?['news2'] != null)
                  HcHeroChip(
                      icon: Icons.monitor_heart_rounded,
                      label: 'NEWS2 ${latest!['news2']}'),
                if (p['adherence_rate'] != null)
                  HcHeroChip(
                      icon: Icons.pie_chart_rounded,
                      label: 'Adherence ${p['adherence_rate']}%'),
              ],
            ),
            // Quick actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => hcOpenDirections(
                      context,
                      destLat: double.tryParse('${p['address_lat']}'),
                      destLng: double.tryParse('${p['address_lng']}'),
                      address: p['address']?.toString(),
                    ),
                    icon: const Icon(Icons.directions_rounded, size: 18),
                    label: const Text('Directions'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () async {
                      final phone =
                          (p['user']?['phone'] ?? '').toString().trim();
                      if (phone.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('No phone number on file.')));
                        return;
                      }
                      await launchUrl(Uri.parse('tel:$phone'));
                    },
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: const Text('Call'),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            HcPanel(
              title: 'Clinical profile',
              icon: Icons.medical_information_rounded,
              color: hcTeal,
              child: Column(children: [
                HcInfoRow(
                    label: 'Diagnosis',
                    value: p['primary_diagnosis']?.toString() ?? '',
                    icon: Icons.local_hospital_rounded),
                HcInfoRow(
                    label: 'Allergies',
                    value: p['allergies']?.toString() ?? '',
                    icon: Icons.dangerous_rounded),
                HcInfoRow(
                    label: 'Address',
                    value: p['address']?.toString() ?? '',
                    icon: Icons.home_rounded),
                HcInfoRow(
                    label: 'Enrolled',
                    value: hcDate(p['enrolled_at']),
                    icon: Icons.event_available_rounded),
              ]),
            ),
            HcPanel(
              title: 'Care team',
              icon: Icons.groups_rounded,
              color: hcBlue,
              child: Column(children: [
                HcInfoRow(
                    label: 'Caregiver',
                    value: p['assigned_caregiver_name']?.toString() ?? '',
                    icon: Icons.medical_services_rounded),
                for (final c
                    in (p['additional_caregivers_detail'] as List?) ?? [])
                  HcInfoRow(
                      label: 'Additional',
                      value: (c as Map)['full_name']?.toString() ?? '',
                      icon: Icons.person_add_alt_rounded),
                if (p['assigned_doctor_info'] is Map &&
                    ((p['assigned_doctor_info'] as Map)['name'] ?? '')
                        .toString()
                        .isNotEmpty)
                  HcInfoRow(
                      label: 'Doctor',
                      value: (p['assigned_doctor_info'] as Map)['name']
                          .toString(),
                      icon: Icons.badge_rounded),
              ]),
            ),
            if (latest != null)
              HcPanel(
                title: 'Latest vitals',
                subtitle: hcDateTime(latest['recorded_at']),
                icon: Icons.monitor_heart_rounded,
                color: hcRose,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in [
                      ('BP', '${latest['systolic'] ?? '—'}/${latest['diastolic'] ?? '—'}'),
                      ('Pulse', '${latest['pulse'] ?? '—'}'),
                      ('SpO₂', '${latest['spo2'] ?? '—'}%'),
                      ('Temp', '${latest['temperature'] ?? '—'}°C'),
                      ('RR', '${latest['rr'] ?? '—'}'),
                      if (latest['news2'] != null)
                        ('NEWS2', '${latest['news2']}'),
                    ])
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: hcRose.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(children: [
                          Text(v.$2,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                          Text(v.$1,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                        ]),
                      ),
                  ],
                ),
              ),
            if (escalations.isNotEmpty)
              HcPanel(
                title: 'Open escalations',
                icon: Icons.warning_amber_rounded,
                color: hcRed,
                child: Column(
                  children: escalations.map<Widget>((e) {
                    final m = e as Map;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(Icons.error_rounded,
                          color: hcSeverityColor(m['severity']?.toString())),
                      title: Text(m['reason']?.toString() ?? '—',
                          maxLines: 2,
                          style: const TextStyle(fontSize: 12.5)),
                      subtitle: Text(hcDateTime(m['triggered_at']),
                          style: const TextStyle(fontSize: 11)),
                      trailing: HcStatusChip(
                          label: hcLabel(m['status']?.toString()),
                          color: m['status'] == 'resolved'
                              ? hcGreen
                              : hcAmber),
                    );
                  }).toList(),
                ),
              ),
            if (contacts.isNotEmpty)
              HcPanel(
                title: 'Emergency contacts',
                icon: Icons.contact_phone_rounded,
                color: hcAmber,
                child: Column(
                  children: contacts.map<Widget>((c) {
                    final m = c as Map;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: HcAvatar(
                          name: m['name']?.toString(),
                          size: 36,
                          color: hcAmber),
                      title: Text(m['name']?.toString() ?? '—',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      subtitle: Text(
                          '${m['relationship'] ?? ''} · ${m['phone'] ?? ''}',
                          style: const TextStyle(fontSize: 11.5)),
                      trailing: IconButton(
                        icon: const Icon(Icons.call_rounded,
                            color: hcGreen, size: 20),
                        onPressed: () async {
                          final phone = (m['phone'] ?? '').toString().trim();
                          if (phone.isNotEmpty) {
                            await launchUrl(Uri.parse('tel:$phone'));
                          }
                        },
                      ),
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
