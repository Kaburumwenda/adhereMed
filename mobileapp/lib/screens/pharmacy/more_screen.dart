import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    final items = <_MoreItem>[
      _MoreItem(icon: Icons.people_rounded, label: 'Customers', path: '/customers', color: Colors.blue),
      _MoreItem(icon: Icons.local_shipping_rounded, label: 'Deliveries', path: '/deliveries', color: Colors.orange),
      _MoreItem(icon: Icons.medication_liquid_rounded, label: l?.catalog ?? 'Catalog', path: '/catalog', color: Colors.teal),
      _MoreItem(icon: Icons.credit_card_rounded, label: 'Credit Sales', path: '/credits', color: Colors.purple),
      _MoreItem(icon: Icons.receipt_long_rounded, label: 'Sales History', path: '/sales', color: Colors.green),
      _MoreItem(icon: Icons.pause_circle_rounded, label: 'Parked Sales', path: '/pos/parked', color: Colors.amber),
      _MoreItem(icon: Icons.api_rounded, label: 'API Billing', path: '/billing', color: Colors.indigo),
      _MoreItem(icon: Icons.settings_rounded, label: l?.settings ?? 'Settings', path: '/settings', color: Colors.grey),
    ];

    return Scaffold(
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 2),
        itemBuilder: (_, i) {
          final item = items[i];
          return ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            title: Text(item.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant, size: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () => context.go(item.path),
          );
        },
      ),
    );
  }
}

class _MoreItem {
  final IconData icon;
  final String label;
  final String path;
  final Color color;
  const _MoreItem({required this.icon, required this.label, required this.path, required this.color});
}
