import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api.dart';
import '../../core/theme_provider.dart';
import '../../providers/auth_provider.dart';

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

  static const _tabs = [
    _Tab(icon: Icons.dashboard_rounded, label: 'Home', path: '/'),
    _Tab(icon: Icons.inventory_2_rounded, label: 'Inventory', path: '/inventory'),
    _Tab(icon: Icons.analytics_rounded, label: 'Analytics', path: '/analytics'),
    _Tab(icon: Icons.card_giftcard_rounded, label: 'Referrals', path: '/referral'),
    _Tab(icon: Icons.more_horiz_rounded, label: 'More', path: '/more'),
  ];

  void _onTabTap(int i) {
    if (i == 4) {
      _showMoreMenu();
      return;
    }
    context.go(_tabs[i].path);
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MoreSheet(onNavigate: (path) {
        Navigator.pop(context);
        context.go(path);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final cs = Theme.of(context).colorScheme;
    final loc = GoRouterState.of(context).matchedLocation;

    // Sync tab index with route
    int activeIdx = 0;
    if (loc.startsWith('/inventory') || loc.startsWith('/categories') || loc.startsWith('/adjustments') || loc.startsWith('/stock-take') || loc.startsWith('/transfers')) {
      activeIdx = 1;
    } else if (loc.startsWith('/analytics')) {
      activeIdx = 2;
    } else if (loc.startsWith('/referral')) {
      activeIdx = 3;
    } else if (loc == '/') {
      activeIdx = 0;
    } else {
      activeIdx = 4;
    }

    final hideShellChrome = loc.startsWith('/pos');

    return Scaffold(
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
              const PopupMenuItem(value: 'settings', child: ListTile(dense: true, leading: Icon(Icons.settings), title: Text('Settings'))),
              PopupMenuItem(value: 'logout', child: ListTile(dense: true, leading: Icon(Icons.logout, color: cs.error), title: Text('Sign Out', style: TextStyle(color: cs.error)))),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: widget.child,
      bottomNavigationBar: hideShellChrome ? null : NavigationBar(
        selectedIndex: activeIdx.clamp(0, 4),
        onDestinationSelected: _onTabTap,
        destinations: _tabs.map((t) => NavigationDestination(icon: Icon(t.icon), label: t.label)).toList(),
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

class _MoreSheet extends StatelessWidget {
  final void Function(String path) onNavigate;
  const _MoreSheet({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('More', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Wrap(spacing: 12, runSpacing: 12, children: [
              _tile(context, Icons.point_of_sale, 'Sales', '/sales'),
              _tile(context, Icons.account_balance, 'Accounts', '/accounts'),
              _tile(context, Icons.receipt, 'Expenses', '/expenses'),
              _tile(context, Icons.assessment, 'Reports', '/reports'),
              _tile(context, Icons.people, 'Staff', '/staff'),
              _tile(context, Icons.person, 'Customers', '/customers'),
              _tile(context, Icons.local_shipping, 'Suppliers', '/suppliers'),
              _tile(context, Icons.local_shipping_outlined, 'Deliveries', '/deliveries'),
              _tile(context, Icons.medication, 'Prescriptions', '/prescriptions'),
              _tile(context, Icons.shield, 'Insurance', '/insurance'),
              _tile(context, Icons.card_giftcard, 'Referrals', '/referral'),
              _tile(context, Icons.medication_liquid, 'Catalog', '/catalog'),
              _tile(context, Icons.api, 'API Billing', '/billing'),
              _tile(context, Icons.store, 'Branches', '/branches'),
              _tile(context, Icons.shopping_cart, 'Purchase Orders', '/purchase-orders'),
              _tile(context, Icons.compare_arrows, 'Transfers', '/transfers'),
              _tile(context, Icons.assignment, 'Stock Take', '/stock-take'),
              _tile(context, Icons.notifications, 'Alerts', '/alerts'),
              _tile(context, Icons.settings, 'Settings', '/settings'),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _tile(BuildContext ctx, IconData icon, String label, String path) {
    final cs = Theme.of(ctx).colorScheme;
    return InkWell(
      onTap: () => onNavigate(path),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: cs.primary, size: 28),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(ctx).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
