import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/theme_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/branch_provider.dart';

/// Count of stock alerts (low stock + expiring)
final _stockAlertCountProvider = FutureProvider.autoDispose((ref) async {
  try {
    final dio = ref.read(dioProvider);
    final results = await Future.wait([
      dio.get('/inventory/stocks/low_stock/'),
      dio.get('/inventory/stocks/expiring_soon/', queryParameters: {'days': 90}),
    ]);
    final low = results[0].data is List ? (results[0].data as List).length : ((results[0].data?['results'] as List?)?.length ?? 0);
    final exp = results[1].data is List ? (results[1].data as List).length : ((results[1].data?['results'] as List?)?.length ?? 0);
    return low + exp;
  } catch (_) {
    return 0;
  }
});

class ShellScreen extends ConsumerStatefulWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});
  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {

  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    // Delay branch init to after the first frame so the Activity is fully
    // rendered and permission dialogs can appear.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initBranches();
    });
  }

  Future<void> _initBranches() async {
    final notifier = ref.read(branchProvider.notifier);
    await notifier.load();
    await notifier.autoAssignNearest();
  }

  List<_Tab> _tabs(AppLocalizations? l) {
    final role = ref.read(authProvider).user?.role ?? '';
    final isSoftAssign = const {'cashier', 'pharmacist', 'pharmacy_tech'}.contains(role);

    if (isSoftAssign) {
      // Restricted nav for soft-assign roles
      return [
        _Tab(icon: Icons.dashboard_rounded, label: l?.dashboard ?? 'Home', path: '/'),
        _Tab(icon: Icons.inventory_2_rounded, label: l?.inventory ?? 'Inventory', path: '/inventory'),
        _Tab(icon: Icons.people_rounded, label: 'Customers', path: '/customers'),
        _Tab(icon: Icons.medication_liquid_rounded, label: l?.catalog ?? 'Catalog', path: '/catalog'),
        _Tab(icon: Icons.local_shipping_rounded, label: 'Delivers', path: '/deliveries'),
      ];
    }

    // Full nav for admin roles (branch_admin, tenant_admin, super_admin)
    return [
      _Tab(icon: Icons.dashboard_rounded, label: l?.dashboard ?? 'Home', path: '/'),
      _Tab(icon: Icons.inventory_2_rounded, label: l?.inventory ?? 'Inventory', path: '/inventory'),
      _Tab(icon: Icons.analytics_rounded, label: 'Analytics', path: '/analytics'),
      _Tab(icon: Icons.card_giftcard_rounded, label: l?.referrals ?? 'Referrals', path: '/referral'),
      _Tab(icon: Icons.more_horiz_rounded, label: 'More', path: '/more'),
    ];
  }

  void _onTabTap(int i) {
    final tabs = _tabs(AppLocalizations.of(context));
    context.go(tabs[i].path);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final cs = Theme.of(context).colorScheme;
    final loc = GoRouterState.of(context).matchedLocation;
    final l = AppLocalizations.of(context);
    final tabs = _tabs(l);

    // Sync tab index with route
    int activeIdx = 0;
    final role = auth.user?.role ?? '';
    final isSoftAssign = const {'cashier', 'pharmacist', 'pharmacy_tech'}.contains(role);

    if (isSoftAssign) {
      if (loc.startsWith('/inventory') || loc.startsWith('/categories') || loc.startsWith('/adjustments') || loc.startsWith('/stock-take') || loc.startsWith('/transfers')) {
        activeIdx = 1;
      } else if (loc.startsWith('/customers')) {
        activeIdx = 2;
      } else if (loc.startsWith('/catalog')) {
        activeIdx = 3;
      } else if (loc.startsWith('/deliveries')) {
        activeIdx = 4;
      }
    } else {
      if (loc.startsWith('/inventory') || loc.startsWith('/categories') || loc.startsWith('/adjustments') || loc.startsWith('/stock-take') || loc.startsWith('/transfers')) {
        activeIdx = 1;
      } else if (loc.startsWith('/analytics')) {
        activeIdx = 2;
      } else if (loc.startsWith('/referral')) {
        activeIdx = 3;
      } else if (loc.startsWith('/more') || loc.startsWith('/customers') || loc.startsWith('/deliveries') || loc.startsWith('/catalog')) {
        activeIdx = 4;
      }
    }

    final hideShellChrome = loc.startsWith('/pos');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // If not on dashboard, go back to dashboard
        if (loc != '/') {
          context.go('/');
          return;
        }
        // On dashboard: double-back to exit
        final now = DateTime.now();
        if (_lastBackPress != null && now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
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
      appBar: hideShellChrome ? null : AppBar(
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.local_pharmacy, size: 20, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(auth.user?.tenantName ?? 'AdhereMed', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17), overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          IconButton(
            icon: Icon(
              ref.watch(themeModeProvider) == ThemeMode.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
            ),
            tooltip: 'Toggle theme',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: (ref.watch(_stockAlertCountProvider).valueOrNull ?? 0) > 0,
              label: Text('${ref.watch(_stockAlertCountProvider).valueOrNull ?? 0}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700)),
              backgroundColor: const Color(0xFFEF4444),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => context.go('/alerts'),
          ),
          PopupMenuButton<String>(
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: cs.primaryContainer,
                child: Text(auth.user?.initials ?? '?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary)),
              ),
            ),
            onSelected: (v) {
              if (v == 'settings') context.go('/settings');
              if (v == 'logout') ref.read(authProvider.notifier).logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(auth.user?.fullName ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(auth.user?.email ?? '', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ])),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'settings', child: ListTile(dense: true, leading: const Icon(Icons.settings), title: Text(l?.settings ?? 'Settings'))),
              PopupMenuItem(value: 'logout', child: ListTile(dense: true, leading: Icon(Icons.logout, color: cs.error), title: Text(l?.logout ?? 'Sign Out', style: TextStyle(color: cs.error)))),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: widget.child,
      bottomNavigationBar: hideShellChrome ? null : NavigationBar(
        selectedIndex: activeIdx.clamp(0, 4),
        onDestinationSelected: _onTabTap,
        destinations: tabs.map((t) => NavigationDestination(icon: Icon(t.icon), label: t.label)).toList(),
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
