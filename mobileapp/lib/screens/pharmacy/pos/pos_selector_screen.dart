import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class POSSelectorScreen extends StatelessWidget {
  const POSSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F0F17) : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.go('/'),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.arrow_back_rounded,
                      size: 20, color: cs.onSurface),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text('Point of Sale',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface)),
              ),
            ]),
          ),

          // Center content
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.storefront_rounded,
                            size: 48, color: cs.primary),
                      ),
                      const SizedBox(height: 20),
                      Text('Choose POS Mode',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface)),
                      const SizedBox(height: 8),
                      Text('Select the mode that fits your workflow',
                          style: TextStyle(
                              fontSize: 14, color: cs.onSurfaceVariant)),
                      const SizedBox(height: 36),

                      // Pharmacy POS card
                      _ModeCard(
                        icon: Icons.local_pharmacy_rounded,
                        title: 'Pharmacy POS',
                        subtitle: 'Browse products by category, search and add to cart',
                        color: cs.primary,
                        features: const [
                          'Product grid with categories',
                          'Visual product browsing',
                          'Full product details',
                        ],
                        onTap: () => context.go('/pos/pharmacy'),
                      ),
                      const SizedBox(height: 16),

                      // Smart POS card
                      _ModeCard(
                        icon: Icons.flash_on_rounded,
                        title: 'Smart POS',
                        subtitle: 'Fast checkout — scan barcode or search by name/SKU',
                        color: Colors.amber.shade700,
                        features: const [
                          'Barcode scanning',
                          'Quick name / SKU search',
                          'Optimized for speed',
                        ],
                        onTap: () => context.go('/pos/smart'),
                      ),
                    ]
                        .animate(interval: 100.ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final List<String> features;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.features,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: color.withValues(alpha: 0.15), width: 1.5),
          ),
          child: Row(children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: cs.onSurface)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: features
                          .map((f) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    size: 12, color: color),
                                const SizedBox(width: 4),
                                Text(f,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurfaceVariant)),
                              ]))
                          .toList(),
                    ),
                  ]),
            ),
            Icon(Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant, size: 24),
          ]),
        ),
      ),
    );
  }
}
