import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import 'hc_common.dart';

/// "More" hub — every secondary homecare module in one place.
class HomecareMoreScreen extends ConsumerWidget {
  const HomecareMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(authProvider).user?.role != 'caregiver';

    final sections = <(String, List<(IconData, String, String, Color)>)>[
      (
        'Care Operations',
        [
          (Icons.groups_rounded, 'Patients', '/homecare/patients', hcBlue),
          (Icons.healing_rounded, 'Patient Care', '/homecare/patient-care', hcTeal),
          (Icons.assignment_rounded, 'Assessments', '/homecare/assessments', hcPurple),
          (Icons.monitor_heart_rounded, 'Vitals & Observations', '/homecare/vitals', hcRose),
          (Icons.note_alt_rounded, 'Care Notes', '/homecare/notes', hcTeal),
        ]
      ),
      (
        'Medications',
        [
          (Icons.medication_rounded, 'Doses', '/homecare/doses', hcBlue),
          (Icons.receipt_rounded, 'Prescriptions', '/homecare/prescriptions', hcRose),
          (Icons.article_rounded, 'Treatment Plans', '/homecare/treatment-plans', hcGreen),
          (Icons.query_stats_rounded, 'Dose Analysis', '/homecare/doses-analysis', hcBlue),
          (Icons.inventory_rounded, 'Stock Alerts', '/homecare/stock-alerts', hcAmber),
          (Icons.gpp_maybe_rounded, 'Drug Safety', '/homecare/drug-safety', hcRed),
        ]
      ),
      (
        'Telehealth & Alerts',
        [
          (Icons.videocam_rounded, 'Teleconsult', '/homecare/teleconsult', hcIndigo),
          (Icons.notification_important_rounded, 'Escalations', '/homecare/escalations', hcRed),
          (Icons.forum_rounded, 'Inbox', '/homecare/inbox', hcGreen),
          (Icons.mail_rounded, 'Mail', '/homecare/mail', hcBlue),
        ]
      ),
      (
        'Clinical Tools',
        [
          (Icons.calculate_rounded, 'EWS Scoring', '/homecare/ews', hcTeal),
          (Icons.menu_book_rounded, 'Clinical Protocols', '/homecare/protocols', hcIndigo),
          (Icons.library_books_rounded, 'Clinical Catalog', '/homecare/catalog', hcPurple),
          (Icons.route_rounded, 'Care Pathways', '/homecare/care-pathways', hcGreen),
        ]
      ),
      (
        'Settings',
        [
          (Icons.notifications_active_rounded, 'Notifications', '/homecare/notification-settings', hcTeal),
        ]
      ),
      if (isAdmin)
        (
          'Analytics',
          [
            (Icons.insights_rounded, 'Reports', '/homecare/reports', hcTeal),
            (Icons.business_rounded, 'Company Profile', '/homecare/company-profile', hcTeal),
          ]
        ),
      if (isAdmin)
        (
          'Security & Privacy',
          [
            (Icons.fact_check_rounded, 'Consents', '/homecare/consents', hcTeal),
            (Icons.share_rounded, 'Data Sharing', '/homecare/data-sharing', hcSlate),
            (Icons.history_edu_rounded, 'Audit Log', '/homecare/audit', hcSlate),
          ]
        ),
      if (isAdmin)
        (
          'Admin & Management',
          [
            (Icons.medical_services_rounded, 'Caregivers', '/homecare/caregivers', hcBlue),
            (Icons.monitor_heart_rounded, 'Caregiver Monitor', '/homecare/caregiver-monitor', hcTeal),
            (Icons.assignment_ind_rounded, 'Assignments', '/homecare/assignments', hcIndigo),
            (Icons.calendar_month_rounded, 'Schedules', '/homecare/schedules', hcAmber),
            (Icons.medical_information_rounded, 'Equipment', '/homecare/equipment', hcIndigo),
            (Icons.shield_rounded, 'Insurance', '/homecare/insurance', hcBlue),
            (Icons.badge_rounded, 'Human Resources', '/homecare/hr', const Color(0xFFEA580C)),
            (Icons.rule_folder_rounded, 'Escalation Rules', '/homecare/escalation-rules', hcRed),
            (Icons.analytics_rounded, 'Analytics', '/homecare/analytics', hcPurple),
          ]
        ),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const HcHero(
          eyebrow: 'ALL MODULES',
          title: 'More',
          subtitle: 'Everything in your homecare workspace',
          icon: Icons.apps_rounded,
        ),
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
            child: Text(section.$1.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.6,
              children: section.$2
                  .map((m) => Material(
                        color: m.$4.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => context.go(m.$3),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(children: [
                              Icon(m.$1, color: m.$4, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(m.$2,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: m.$4,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5)),
                              ),
                            ]),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
