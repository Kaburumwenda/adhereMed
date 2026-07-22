import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/notifications.dart';
import 'hc_common.dart';

/// Caregiver notification & alert preferences.
///
/// Each reminder category can be tuned independently: the number of
/// minutes before the event the local notification should fire. A
/// master switch silences every reminder at once.
class HomecareNotificationSettingsScreen extends ConsumerWidget {
  const HomecareNotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    final categories = <_ReminderCategory>[
      _ReminderCategory(
        key: 'doses',
        icon: Icons.medication_rounded,
        color: hcBlue,
        title: 'Dose reminders',
        subtitle:
            'Alerts before a medication dose is due for a patient.',
        value: settings.dosesMinutes,
        onChanged: (v) => notifier.update(
            settings.copyWith(dosesMinutes: v)),
      ),
      _ReminderCategory(
        key: 'assessments',
        icon: Icons.assignment_rounded,
        color: hcPurple,
        title: 'Assessment reminders',
        subtitle: 'Alerts before patient assessments are due.',
        value: settings.assessmentsMinutes,
        onChanged: (v) => notifier.update(
            settings.copyWith(assessmentsMinutes: v)),
      ),
      _ReminderCategory(
        key: 'checkIn',
        icon: Icons.login_rounded,
        color: hcTeal,
        title: 'Check-in reminders',
        subtitle: 'Alerts before a visit is due to start.',
        value: settings.checkInMinutes,
        onChanged: (v) => notifier.update(
            settings.copyWith(checkInMinutes: v)),
      ),
      _ReminderCategory(
        key: 'checkOut',
        icon: Icons.logout_rounded,
        color: hcGreen,
        title: 'Check-out reminders',
        subtitle: 'Alerts before a visit is due to end.',
        value: settings.checkOutMinutes,
        onChanged: (v) => notifier.update(
            settings.copyWith(checkOutMinutes: v)),
      ),
      _ReminderCategory(
        key: 'assignments',
        icon: Icons.event_note_rounded,
        color: hcIndigo,
        title: 'Assignment reminders',
        subtitle: 'Alerts before a scheduled shift begins.',
        value: settings.assignmentsMinutes,
        onChanged: (v) => notifier.update(
            settings.copyWith(assignmentsMinutes: v)),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const HcHero(
          eyebrow: 'SETTINGS',
          title: 'Notifications',
          subtitle:
              'Tune how early you get dose, assessment and shift reminders.',
          icon: Icons.notifications_active_rounded,
        ),

        // ── Master switch ──
        Card(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (settings.enabled ? hcTeal : cs.onSurfaceVariant)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                settings.enabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                color: settings.enabled ? hcTeal : cs.onSurfaceVariant,
                size: 22,
              ),
            ),
            title: const Text('Reminders',
                style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(settings.enabled
                ? 'Local notifications are ON.'
                : 'All reminders are muted.'),
            value: settings.enabled,
            activeThumbColor: hcTeal,
            onChanged: (v) async {
              await notifier.update(settings.copyWith(enabled: v));
              if (v) {
                await NotificationService.instance.ensurePermission();
              }
              await NotificationService.instance.scheduleAllReminders(
                dio: ref.read(dioProvider),
                settings: ref.read(notificationSettingsProvider),
              );
            },
          ),
        ),

        // ── Permission helper ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Card(
            margin: EdgeInsets.zero,
            color: hcAmber.withValues(alpha: 0.10),
            child: ListTile(
              leading: const Icon(Icons.shield_rounded, color: hcAmber),
              title: const Text('System permissions',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              subtitle: const Text(
                  'Tap to verify the app is allowed to show notifications.',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final ok =
                    await NotificationService.instance.ensurePermission();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok
                      ? 'Notifications are allowed.'
                      : 'Notifications are blocked — enable them in Settings.'),
                  behavior: SnackBarBehavior.floating,
                ));
              },
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ── Reminder categories ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 16, 8),
          child: Text('REMINDER TIMING'.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: cs.onSurfaceVariant)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final c in categories) ...[
                  _ReminderTile(
                    icon: c.icon,
                    color: c.color,
                    title: c.title,
                    subtitle: c.subtitle,
                    minutes: c.value,
                    enabled: settings.enabled,
                    onChanged: (v) async {
                      await c.onChanged(v);
                      await NotificationService.instance.scheduleAllReminders(
                        dio: ref.read(dioProvider),
                        settings: ref.read(notificationSettingsProvider),
                      );
                    },
                  ),
                  if (c.key != 'assignments')
                    const Divider(height: 1, indent: 56),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Reschedule / test buttons ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  await NotificationService.instance.scheduleAllReminders(
                    dio: ref.read(dioProvider),
                    settings: ref.read(notificationSettingsProvider),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Reminders rescheduled for today.'),
                    behavior: SnackBarBehavior.floating,
                  ));
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reschedule now'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _sendTest(context),
              icon: const Icon(Icons.bolt_rounded),
              label: const Text('Test'),
            ),
          ]),
        ),

        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Reminders are scheduled locally on this device and fire even '
            'when the app is closed. Times shown are minutes before the '
            'event.',
            style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Future<void> _sendTest(BuildContext context) async {
    await NotificationService.instance.ensurePermission();
    await NotificationService.instance.sendTestNotification();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Test notification sent.'),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

class _ReminderCategory {
  final String key;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int value;
  final Future<void> Function(int) onChanged;
  const _ReminderCategory({
    required this.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
}

class _ReminderTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int minutes;
  final bool enabled;
  final Future<void> Function(int) onChanged;
  const _ReminderTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.minutes,
    required this.enabled,
    required this.onChanged,
  });

  static const _presets = [5, 10, 15, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: PopupMenuButton<int>(
          enabled: enabled,
          tooltip: '$minutes min before',
          itemBuilder: (_) => _presets
              .map((m) => PopupMenuItem(
                    value: m,
                    child: Row(children: [
                      Icon(minutes == m
                          ? Icons.check_circle_rounded
                          : Icons.schedule_rounded,
                          size: 16,
                          color: minutes == m ? color : cs.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text('$m min before'),
                    ]),
                  ))
              .toList(),
          onSelected: onChanged,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.schedule_rounded, size: 14, color: color),
              const SizedBox(width: 4),
              Text('$minutes min',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w800, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}
