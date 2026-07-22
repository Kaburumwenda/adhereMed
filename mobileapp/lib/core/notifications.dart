import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

// ═════════════════════════════════════════════════════════════════
//  Notification & Alerts module for the Homecare caregivers.
//
//  Schedules local reminders 30 minutes (configurable) before:
//    • Medication doses
//    • Patient assessments (visit-linked)
//    • Visit check-in  (shift start)
//    • Visit check-out (shift end)
//    • Assignments / shifts coming up
//
//  Uses awesome_notifications ^0.12.1 for local scheduling so the
//  reminders fire even when the app is in the background or closed.
// ═════════════════════════════════════════════════════════════════

const String kRemindersChannelKey = 'hc_reminders';

/// Per-category reminder configuration stored in SharedPreferences.
class NotificationSettings {
  final bool enabled;
  final int dosesMinutes;
  final int assessmentsMinutes;
  final int checkInMinutes;
  final int checkOutMinutes;
  final int assignmentsMinutes;

  const NotificationSettings({
    this.enabled = true,
    this.dosesMinutes = 30,
    this.assessmentsMinutes = 30,
    this.checkInMinutes = 30,
    this.checkOutMinutes = 30,
    this.assignmentsMinutes = 30,
  });

  NotificationSettings copyWith({
    bool? enabled,
    int? dosesMinutes,
    int? assessmentsMinutes,
    int? checkInMinutes,
    int? checkOutMinutes,
    int? assignmentsMinutes,
  }) =>
      NotificationSettings(
        enabled: enabled ?? this.enabled,
        dosesMinutes: dosesMinutes ?? this.dosesMinutes,
        assessmentsMinutes: assessmentsMinutes ?? this.assessmentsMinutes,
        checkInMinutes: checkInMinutes ?? this.checkInMinutes,
        checkOutMinutes: checkOutMinutes ?? this.checkOutMinutes,
        assignmentsMinutes: assignmentsMinutes ?? this.assignmentsMinutes,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'doses_minutes': dosesMinutes,
        'assessments_minutes': assessmentsMinutes,
        'check_in_minutes': checkInMinutes,
        'check_out_minutes': checkOutMinutes,
        'assignments_minutes': assignmentsMinutes,
      };

  factory NotificationSettings.fromJson(Map<String, dynamic> j) =>
      NotificationSettings(
        enabled: j['enabled'] as bool? ?? true,
        dosesMinutes: (j['doses_minutes'] as num?)?.toInt() ?? 30,
        assessmentsMinutes: (j['assessments_minutes'] as num?)?.toInt() ?? 30,
        checkInMinutes: (j['check_in_minutes'] as num?)?.toInt() ?? 30,
        checkOutMinutes: (j['check_out_minutes'] as num?)?.toInt() ?? 30,
        assignmentsMinutes: (j['assignments_minutes'] as num?)?.toInt() ?? 30,
      );

  static const _key = 'hc_notification_settings';

  static Future<NotificationSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const NotificationSettings();
    try {
      return NotificationSettings.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return const NotificationSettings();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }
}

// ── Provider ──────────────────────────────────────────────────────

class NotificationSettingsNotifier
    extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier() : super(const NotificationSettings()) {
    _load();
  }

  Future<void> _load() async {
    state = await NotificationSettings.load();
  }

  Future<void> update(NotificationSettings next) async {
    state = next;
    await next.save();
  }
}

final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
        (ref) => NotificationSettingsNotifier());

// ── Service ───────────────────────────────────────────────────────

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  bool _initialized = false;

  static const Color _brand = Color(0xFF0D9488);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: kRemindersChannelKey,
          channelName: 'Caregiver Reminders',
          channelDescription:
              'Dose, assessment, check-in/out and assignment reminders.',
          importance: NotificationImportance.High,
          defaultColor: _brand,
          ledColor: _brand,
          playSound: true,
          enableLights: true,
          enableVibration: true,
          criticalAlerts: true,
        ),
      ],
      debug: false,
    );

    // Listen for taps so we can deep-link into the right screen.
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onActionReceived,
    );
  }

  /// Request the OS-level permission to post notifications (Android 13+).
  Future<bool> ensurePermission() async {
    final ok = await AwesomeNotifications().isNotificationAllowed();
    if (ok) return true;
    return AwesomeNotifications().requestPermissionToSendNotifications(
      channelKey: kRemindersChannelKey,
      permissions: const [
        NotificationPermission.Alert,
        NotificationPermission.Sound,
        NotificationPermission.Vibration,
        NotificationPermission.Badge,
      ],
    );
  }

  Future<void> _onActionReceived(ReceivedAction action) async {
    // Payload carries a route to deep-link; handled by the router via a
    // global navigator key in main.dart. We simply store the last action.
    final route = action.payload?['route'];
    if (route is String && route.isNotEmpty) {
      NotificationService.pendingRoute = route;
    }
  }

  /// Route awaiting navigation after a notification tap.
  static String? pendingRoute;

  // ── Scheduling ─────────────────────────────────────────────────

  /// Pull the caregiver's day from the API and schedule every reminder
  /// using the current [NotificationSettings]. Call this on app start,
  /// on login and whenever the caregiver opens the Homecare shell.
  ///
  /// [dio] and [settings] are passed in so the method works from both
  /// `ConsumerWidget`s (which hold a `WidgetRef`) and plain providers
  /// (which hold a `Ref`).
  Future<void> scheduleAllReminders({
    required Dio dio,
    required NotificationSettings settings,
  }) async {
    await init();
    // Always clear previously scheduled reminders so we never duplicate.
    await AwesomeNotifications().cancelAllSchedules();

    if (!settings.enabled) return;

    try {
      final res = await dio.get('/homecare/caregivers/me/my-day/');
      final data = res.data is Map ? res.data as Map<String, dynamic> : {};
      final visits = (data['visits'] as List?) ?? const [];
      final doses = (data['doses'] as List?) ?? const [];

      final now = DateTime.now();

      // ── Dose reminders ──
      for (final d in doses) {
        if ((d['status']?.toString()) != 'pending') continue;
        final at = DateTime.tryParse(d['scheduled_at']?.toString() ?? '')
            ?.toLocal();
        if (at == null) continue;
        final fire = at.subtract(Duration(minutes: settings.dosesMinutes));
        if (fire.isBefore(now)) continue;
        await _schedule(
          id: _idHash('dose_${d['id']}'),
          title: 'Medication dose reminder',
          body:
              '${d['medication_name'] ?? d['drug_name'] ?? 'A dose'} for ${d['patient_name'] ?? 'patient'} at ${_hhmm(at)}.',
          fire: fire,
          route: '/homecare/doses',
          category: NotificationCategory.Reminder,
        );
      }

      // ── Visit-linked reminders (check-in / check-out / assessment / assignment) ──
      for (final v in visits) {
        final status = v['status']?.toString();
        if (status == 'cancelled' || status == 'missed') continue;
        final start = DateTime.tryParse(v['start_at']?.toString() ?? '')
            ?.toLocal();
        final end = DateTime.tryParse(v['end_at']?.toString() ?? '')?.toLocal();
        final patient = v['patient_name']?.toString() ?? 'patient';

        // Check-in reminder (before start)
        if (start != null) {
          final fire = start.subtract(Duration(minutes: settings.checkInMinutes));
          if (!fire.isBefore(now) && status == 'scheduled') {
            await _schedule(
              id: _idHash('checkin_${v['id']}'),
              title: 'Check-in reminder',
              body: 'Check in for $patient visit at ${_hhmm(start)}.',
              fire: fire,
              route: '/homecare/my-day',
              category: NotificationCategory.Reminder,
            );
          }

          // Assignment reminder (the shift is coming up)
          final aFire =
              start.subtract(Duration(minutes: settings.assignmentsMinutes));
          if (!aFire.isBefore(now)) {
            await _schedule(
              id: _idHash('assign_${v['id']}'),
              title: 'Assignment reminder',
              body: '${v['shift_type_label'] ?? 'Visit'} with $patient starts at ${_hhmm(start)}.',
              fire: aFire,
              route: '/homecare/assignments',
              category: NotificationCategory.Reminder,
            );
          }

          // Assessment reminder (assessments are performed at visit start)
          final asFire = start.subtract(
              Duration(minutes: settings.assessmentsMinutes));
          if (!asFire.isBefore(now)) {
            await _schedule(
              id: _idHash('assess_${v['id']}'),
              title: 'Assessment reminder',
              body: 'Patient assessments for $patient are due at ${_hhmm(start)}.',
              fire: asFire,
              route: '/homecare/assessments',
              category: NotificationCategory.Reminder,
            );
          }
        }

        // Check-out reminder (before end)
        if (end != null) {
          final fire = end.subtract(Duration(minutes: settings.checkOutMinutes));
          if (!fire.isBefore(now) && status != 'completed') {
            await _schedule(
              id: _idHash('checkout_${v['id']}'),
              title: 'Check-out reminder',
              body: 'Check out for $patient visit ends at ${_hhmm(end)}.',
              fire: fire,
              route: '/homecare/my-day',
              category: NotificationCategory.Reminder,
            );
          }
        }
      }
    } catch (_) {
      // Network errors are non-fatal — reminders will retry on next launch.
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fire,
    required String route,
    NotificationCategory category = NotificationCategory.Reminder,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: kRemindersChannelKey,
        title: title,
        body: body,
        wakeUpScreen: true,
        category: category,
        payload: {'route': route},
        notificationLayout: NotificationLayout.Default,
        autoDismissible: false,
      ),
      schedule: NotificationCalendar.fromDate(
        date: fire,
        preciseAlarm: true,
        allowWhileIdle: true,
      ),
    );
  }

  /// Fire an immediate notification so the caregiver can confirm the
  /// channel works (used by the "Test" button on the settings screen).
  Future<void> sendTestNotification() async {
    await init();
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: _idHash('test'),
        channelKey: kRemindersChannelKey,
        title: 'AdhereMed reminders are working',
        body: 'You will be alerted before doses, assessments and shifts.',
        wakeUpScreen: true,
        category: NotificationCategory.Reminder,
        payload: {'route': '/homecare/notification-settings'},
        notificationLayout: NotificationLayout.Default,
      ),
    );
  }

  int _idHash(String key) {
    var h = 0;
    for (var i = 0; i < key.length; i++) {
      h = (h * 31 + key.codeUnitAt(i)) & 0x7fffffff;
    }
    return h;
  }

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Convenience provider to trigger a full re-schedule from the UI.
final rescheduleRemindersProvider = FutureProvider<void>((ref) async {
  await NotificationService.instance.scheduleAllReminders(
    dio: ref.read(dioProvider),
    settings: ref.read(notificationSettingsProvider),
  );
});
