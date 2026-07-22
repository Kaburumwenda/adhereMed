import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme_provider.dart';
import '../../core/notifications.dart';
import '../../core/api.dart';
import '../../providers/auth_provider.dart';
import 'hc_common.dart';

/// Shell for the Homecare module — teal-branded app bar + role-aware
/// bottom navigation (admins manage, caregivers work in the field).
class HomecareShellScreen extends ConsumerStatefulWidget {
  final Widget child;
  const HomecareShellScreen({super.key, required this.child});

  @override
  ConsumerState<HomecareShellScreen> createState() =>
      _HomecareShellScreenState();
}

class _HomecareShellScreenState extends ConsumerState<HomecareShellScreen> {
  DateTime? _lastBackPress;

  bool get _isCaregiver => ref.read(authProvider).user?.role == 'caregiver';

  @override
  void initState() {
    super.initState();
    // Refresh the locally-scheduled reminders whenever the caregiver
    // enters the Homecare workspace (today's visits & doses may have
    // changed since the last launch).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = ref.read(authProvider);
      if (auth.isLoggedIn && auth.tenantType == 'homecare') {
        await NotificationService.instance.ensurePermission();
        await NotificationService.instance.scheduleAllReminders(
          dio: ref.read(dioProvider),
          settings: ref.read(notificationSettingsProvider),
        );
      }
      // Deep-link from a notification tap (cold launch).
      final route = NotificationService.pendingRoute;
      if (route is String && route.startsWith('/homecare')) {
        NotificationService.pendingRoute = null;
        if (mounted) context.go(route);
      }
    });
  }

  List<_Tab> get _tabs {
    if (_isCaregiver) {
      return const [
        _Tab(icon: Icons.dashboard_rounded, label: 'Home', path: '/homecare'),
        _Tab(icon: Icons.today_rounded, label: 'My Day', path: '/homecare/my-day'),
        _Tab(icon: Icons.volunteer_activism_rounded, label: 'Care', path: '/homecare/patient-care'),
        _Tab(icon: Icons.event_note_rounded, label: 'Shifts', path: '/homecare/assignments'),
        _Tab(icon: Icons.apps_rounded, label: 'More', path: '/homecare/more'),
      ];
    }
    return const [
      _Tab(icon: Icons.dashboard_rounded, label: 'Home', path: '/homecare'),
      _Tab(icon: Icons.analytics_rounded, label: 'Analytics', path: '/homecare/analytics'),
      _Tab(icon: Icons.volunteer_activism_rounded, label: 'Care', path: '/homecare/patient-care'),
      _Tab(icon: Icons.event_note_rounded, label: 'Shifts', path: '/homecare/assignments'),
      _Tab(icon: Icons.apps_rounded, label: 'More', path: '/homecare/more'),
    ];
  }

  int _activeIndex(String loc) {
    final tabs = _tabs;
    // Longest-prefix match so /homecare/patients/5 highlights Patients.
    var best = 0;
    var bestLen = -1;
    for (var i = 0; i < tabs.length; i++) {
      final p = tabs[i].path;
      if ((loc == p || loc.startsWith('$p/')) && p.length > bestLen) {
        best = i;
        bestLen = p.length;
      }
    }
    if (bestLen == -1 && loc.startsWith('/homecare')) return 0;
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final cs = Theme.of(context).colorScheme;
    final loc = GoRouterState.of(context).matchedLocation;
    final tabs = _tabs;
    final activeIdx = _activeIndex(loc);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (loc != '/homecare') {
          context.go('/homecare');
          return;
        }
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: hcTeal.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.home_work_rounded, size: 20, color: hcTeal),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(auth.user?.tenantName ?? 'Homecare',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 17),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          actions: [
            IconButton(
              icon: Icon(ref.watch(themeModeProvider) == ThemeMode.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded),
              tooltip: 'Toggle theme',
              onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
            ),
            IconButton(
              icon: const Icon(Icons.notification_important_outlined),
              tooltip: 'Escalations',
              onPressed: () => context.go('/homecare/escalations'),
            ),
            PopupMenuButton<String>(
              offset: const Offset(0, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: hcTeal.withValues(alpha: 0.14),
                  child: Text(auth.user?.initials ?? '?',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: hcTeal)),
                ),
              ),
              onSelected: (v) {
                if (v == 'logout') ref.read(authProvider.notifier).logout();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(auth.user?.fullName ?? '',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        Text(auth.user?.email ?? '',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(hcLabel(auth.user?.role),
                            style: const TextStyle(
                                fontSize: 11,
                                color: hcTeal,
                                fontWeight: FontWeight.w700)),
                      ]),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                        dense: true,
                        leading: Icon(Icons.logout, color: cs.error),
                        title: Text('Sign Out',
                            style: TextStyle(color: cs.error)))),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: widget.child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: activeIdx.clamp(0, tabs.length - 1),
          onDestinationSelected: (i) => context.go(tabs[i].path),
          destinations: tabs
              .map((t) =>
                  NavigationDestination(icon: Icon(t.icon), label: t.label))
              .toList(),
        ),
      ),
    );
  }
}

class _Tab {
  final IconData icon;
  final String label;
  final String path;
  const _Tab({required this.icon, required this.label, required this.path});
}
