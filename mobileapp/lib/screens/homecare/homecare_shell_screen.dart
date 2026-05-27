import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomecareShellScreen extends ConsumerWidget {
  final Widget child;
  const HomecareShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;

    int activeIdx = 0;
    if (loc.startsWith('/homecare/patients')) {
      activeIdx = 1;
    } else if (loc.startsWith('/homecare/schedules')) {
      activeIdx = 2;
    } else if (loc.startsWith('/homecare/my-day')) {
      activeIdx = 3;
    } else if (loc.startsWith('/homecare/caregivers') || loc.startsWith('/homecare/escalations') || loc.startsWith('/homecare/assignments')) {
      activeIdx = 4;
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: activeIdx,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/homecare');
            case 1:
              context.go('/homecare/patients');
            case 2:
              context.go('/homecare/schedules');
            case 3:
              context.go('/homecare/my-day');
            case 4:
              _showMoreMenu(context);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people_alt_rounded), label: 'Patients'),
          NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'Visits'),
          NavigationDestination(icon: Icon(Icons.today_rounded), label: 'My Day'),
          NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'More'),
        ],
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _MoreItem(
                icon: Icons.account_tree_rounded,
                label: 'Assignments',
                color: Colors.indigo,
                onTap: () {
                  Navigator.pop(context);
                  context.go('/homecare/assignments');
                },
              ),
              _MoreItem(
                icon: Icons.group_rounded,
                label: 'Caregivers',
                color: Colors.teal,
                onTap: () {
                  Navigator.pop(context);
                  context.go('/homecare/caregivers');
                },
              ),
              _MoreItem(
                icon: Icons.warning_amber_rounded,
                label: 'Escalations',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  context.go('/homecare/escalations');
                },
              ),
              _MoreItem(
                icon: Icons.settings_rounded,
                label: 'Back to Main App',
                color: cs.onSurfaceVariant,
                onTap: () {
                  Navigator.pop(context);
                  context.go('/');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MoreItem({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }
}
