// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _heroController;
  late AnimationController _staggerController;

  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;
  late Animation<double> _taglineFade;
  late Animation<double> _cardsFade;
  late Animation<Offset> _cardsSlide;
  late Animation<double> _buttonsFade;
  late Animation<Offset> _buttonsSlide;

  @override
  void initState() {
    super.initState();

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoFade = CurvedAnimation(
      parent: _heroController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _heroController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));
    _taglineFade = CurvedAnimation(
      parent: _heroController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );

    _cardsFade = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _cardsSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));

    _buttonsFade = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    );
    _buttonsSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
    ));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _heroController.forward();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _staggerController.forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _heroController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width > 700;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Gradient background ──
          const _GradientBackground(),

          // ── Decorative blobs ──
          Positioned(
            top: -60,
            right: -60,
            child: _Blob(size: 260, color: Colors.white.withOpacity(0.06)),
          ),
          Positioned(
            bottom: 80,
            left: -80,
            child: _Blob(size: 320, color: Colors.white.withOpacity(0.05)),
          ),
          Positioned(
            top: size.height * 0.35,
            right: -40,
            child: _Blob(size: 140, color: Colors.white.withOpacity(0.07)),
          ),

          // ── Content ──
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? size.width * 0.1 : 24,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 72),

                  // ── Logo & Title ──
                  SlideTransition(
                    position: _logoSlide,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: _HeroSection(),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Tagline ──
                  FadeTransition(
                    opacity: _taglineFade,
                    child: Text(
                      'Connected Healthcare.\nSimplified.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isWide ? 22 : 19,
                        fontWeight: FontWeight.w300,
                        color: Colors.white.withOpacity(0.88),
                        height: 1.4,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ── Feature grid ──
                  SlideTransition(
                    position: _cardsSlide,
                    child: FadeTransition(
                      opacity: _cardsFade,
                      child: _FeatureGrid(isWide: isWide),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ── CTA Buttons ──
                  SlideTransition(
                    position: _buttonsSlide,
                    child: FadeTransition(
                      opacity: _buttonsFade,
                      child: _CtaButtons(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Footer ──
                  FadeTransition(
                    opacity: _buttonsFade,
                    child: Text(
                      '© 2026 AdhereMed. Powering Healthcare Excellence.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.45),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Top nav bar (last = on top, receives taps) ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? size.width * 0.1 : 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Logo mark
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.25)),
                      ),
                      child: const Icon(Icons.favorite_rounded,
                          color: Colors.white, size: 17),
                    ),
                    const SizedBox(width: 8),
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'Adhere',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: Colors.white,
                                letterSpacing: -0.3),
                          ),
                          TextSpan(
                            text: 'Med',
                            style: TextStyle(
                                fontWeight: FontWeight.w300,
                                fontSize: 16,
                                color: Colors.white,
                                letterSpacing: -0.3),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Sign In button
                    TextButton(
                      onPressed: () => context.push('/login'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                              color: Colors.white.withOpacity(0.35)),
                        ),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      child: const Text('Sign In'),
                    ),
                    const SizedBox(width: 10),
                    // Register button
                    FilledButton(
                      onPressed: () => context.push('/register/tenant'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F766E),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      child: const Text('Register'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers to access palette without Riverpod ──────────────────────────────

AppColorPalette ref<T>(BuildContext context) {
  // Reads the inherited ThemeExtension-based palette via the theme
  final brightness = Theme.of(context).brightness;
  return brightness == Brightness.dark ? _darkPaletteRef : _lightPaletteRef;
}

// We inline the teal palette for the welcome screen since it always uses
// the brand gradient regardless of user theme.
const _lightPaletteRef = AppColorPalette(
  primary: Color(0xFF0D9488),
  primaryLight: Color(0xFF5EEAD4),
  primaryDark: Color(0xFF0F766E),
  secondary: Color(0xFF6366F1),
  background: Color(0xFFF8FAFC),
  surface: Colors.white,
  error: Color(0xFFEF4444),
  success: Color(0xFF22C55E),
  warning: Color(0xFFF59E0B),
  textPrimary: Color(0xFF1E293B),
  textSecondary: Color(0xFF64748B),
  border: Color(0xFFE2E8F0),
  divider: Color(0xFFF1F5F9),
  brightness: Brightness.light,
);
const _darkPaletteRef = AppColorPalette(
  primary: Color(0xFF2DD4BF),
  primaryLight: Color(0xFF5EEAD4),
  primaryDark: Color(0xFF14B8A6),
  secondary: Color(0xFF818CF8),
  background: Color(0xFF0F172A),
  surface: Color(0xFF1E293B),
  error: Color(0xFFF87171),
  success: Color(0xFF4ADE80),
  warning: Color(0xFFFBBF24),
  textPrimary: Color(0xFFF1F5F9),
  textSecondary: Color(0xFF94A3B8),
  border: Color(0xFF334155),
  divider: Color(0xFF1E293B),
  brightness: Brightness.dark,
);

// ─── Gradient Background ──────────────────────────────────────────────────────

class _GradientBackground extends StatelessWidget {
  const _GradientBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 0.45, 0.75, 1.0],
          colors: [
            Color(0xFF064E3B), // deep emerald
            Color(0xFF0F766E), // teal-700
            Color(0xFF1D4ED8), // blue-700
            Color(0xFF312E81), // indigo-900
          ],
        ),
      ),
    );
  }
}

// ─── Decorative Blob ──────────────────────────────────────────────────────────

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ─── Hero Section ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo mark
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.15),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(52, 52),
              painter: _MedicalCrossPainter(),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // App name
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Adhere',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'Med',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w300,
                  color: Color(0xFF5EEAD4),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.12),
          ),
          child: const Text(
            'Hospital Management Platform',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF99F6E4),
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Medical cross painter ────────────────────────────────────────────────────

class _MedicalCrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final t = w * 0.28; // thickness of each arm

    // Horizontal bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, (h - t) / 2, w, t),
        Radius.circular(t / 2),
      ),
      paint,
    );
    // Vertical bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH((w - t) / 2, 0, t, h),
        Radius.circular(t / 2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Feature Grid ─────────────────────────────────────────────────────────────

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.isWide});
  final bool isWide;

  static const _features = [
    _Feature(Icons.local_hospital_rounded, 'Hospital', 'Wards, OPD & ICU'),
    _Feature(Icons.medical_services_rounded, 'Pharmacy', 'Dispensing & POS'),
    _Feature(Icons.people_alt_rounded, 'Patients', 'Records & History'),
    _Feature(Icons.favorite_rounded, 'Caregivers', 'Care Coordination'),
    _Feature(Icons.biotech_rounded, 'Laboratory', 'Tests & Results'),
    _Feature(Icons.shield_rounded, 'Insurance', 'Claims & Coverage'),
    _Feature(Icons.vaccines_rounded, 'Triage', 'Vitals & Assessment'),
    _Feature(Icons.receipt_long_rounded, 'Billing', 'Invoices & Payments'),
    _Feature(Icons.swap_horiz_rounded, 'Exchange', 'Pharmacy Network'),
  ];

  @override
  Widget build(BuildContext context) {
    final crossCount = isWide ? 5 : 3;
    return GridView.count(
      crossAxisCount: crossCount,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isWide ? 1.1 : 0.95,
      children: _features
          .map((f) => _FeatureCard(feature: f))
          .toList(),
    );
  }
}

class _Feature {
  const _Feature(this.icon, this.label, this.sub);
  final IconData icon;
  final String label;
  final String sub;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature});
  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.10),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
            ),
            child: Icon(
              feature.icon,
              color: const Color(0xFF99F6E4),
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            feature.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            feature.sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CTA Buttons ──────────────────────────────────────────────────────────────

class _CtaButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary: Sign In
        FilledButton(
          onPressed: () => context.go('/login'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F766E),
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          child: const Text('Sign In'),
        ),

        const SizedBox(height: 12),

        // Secondary: Register Facility
        OutlinedButton(
          onPressed: () => context.go('/register-facility'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            side: const BorderSide(color: Colors.white54, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          child: const Text('Register Your Facility'),
        ),

        const SizedBox(height: 16),

        // Tertiary: Register as Doctor / Patient
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SmallLink(
              label: 'Register as Doctor',
              onTap: () => context.go('/register-doctor'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '·',
                style: TextStyle(color: Colors.white.withOpacity(0.4)),
              ),
            ),
            _SmallLink(
              label: 'Patient Sign Up',
              onTap: () => context.go('/register'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SmallLink extends StatelessWidget {
  const _SmallLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF99F6E4),
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
          decorationColor: Color(0xFF99F6E4),
        ),
      ),
    );
  }
}
