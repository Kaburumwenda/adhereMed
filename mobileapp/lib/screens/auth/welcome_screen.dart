import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  COLOR TOKENS  (mirrors nuxtfrontend/pages/welcome.vue dark palette)
// ═══════════════════════════════════════════════════════════════════════════
const _bgDeep = Color(0xFF060B18);
const _bgMid = Color(0xFF081226);
const _bgEdge = Color(0xFF0A1530);
const _bluePrimary = Color(0xFF2563EB);
const _blueLight = Color(0xFF3B82F6);
const _blueSoft = Color(0xFF60A5FA);
const _blueIce = Color(0xFF93C5FD);
const _cyanAccent = Color(0xFF22D3EE);
const _surfaceAlpha = 0.06;
const _strokeAlpha = 0.14;

// ═══════════════════════════════════════════════════════════════════════════
//  DATA
// ═══════════════════════════════════════════════════════════════════════════
class _Stat {
  final String value;
  final String label;
  const _Stat(this.value, this.label);
}

class _OrbitNode {
  final IconData icon;
  final String label;
  const _OrbitNode(this.icon, this.label);
}

class _Actor {
  final IconData icon;
  final String title;
  final String desc;
  const _Actor(this.icon, this.title, this.desc);
}

class _Capability {
  final IconData icon;
  final String title;
  final String desc;
  const _Capability(this.icon, this.title, this.desc);
}

const _stats = [
  _Stat('9+', 'Connected actors'),
  _Stat('91%', 'Avg. adherence'),
  _Stat('99.98%', 'Platform uptime'),
];

const _orbitNodes = [
  _OrbitNode(Icons.favorite_rounded, 'Patient'),
  _OrbitNode(Icons.medical_services_rounded, 'Doctor'),
  _OrbitNode(Icons.local_hospital_rounded, 'Hospital'),
  _OrbitNode(Icons.local_pharmacy_rounded, 'Pharmacy'),
  _OrbitNode(Icons.science_rounded, 'Lab'),
  _OrbitNode(Icons.shield_rounded, 'Insurance'),
  _OrbitNode(Icons.account_balance_rounded, 'Government'),
  _OrbitNode(Icons.show_chart_rounded, 'Analytics'),
];

const _actors = [
  _Actor(Icons.favorite_rounded, 'Patient', 'Engagement, reminders & adherence'),
  _Actor(Icons.medical_services_rounded, 'Doctor', 'Telemedicine & digital prescriptions'),
  _Actor(Icons.local_hospital_rounded, 'Hospital', 'Admissions, EMR & care coordination'),
  _Actor(Icons.local_pharmacy_rounded, 'Pharmacy', 'e-Prescriptions & dispensing'),
  _Actor(Icons.science_rounded, 'Laboratory', 'Orders, results & diagnostics'),
  _Actor(Icons.shield_rounded, 'Insurance', 'Claims, approvals & coverage'),
  _Actor(Icons.account_balance_rounded, 'Government', 'Regulation, reporting & policy'),
  _Actor(Icons.insights_rounded, 'Population Analytics', 'Insights, trends & public health'),
];

const _capabilities = [
  _Capability(Icons.medication_rounded, 'Medication Adherence',
      'Smart reminders, refill tracking and adherence scoring that keep patients on therapy.'),
  _Capability(Icons.video_camera_front_rounded, 'Telemedicine',
      'Secure video consultations, chat and remote triage connecting patients to clinicians anywhere.'),
  _Capability(Icons.edit_document, 'Digital Prescriptions',
      'Paperless e-prescriptions routed instantly to any connected pharmacy with full audit trails.'),
  _Capability(Icons.account_tree_rounded, 'Care Coordination',
      'Shared records and referral workflows that align doctors, hospitals, labs and homecare.'),
  _Capability(Icons.groups_rounded, 'Patient Engagement',
      'Personalised education, surveys and notifications in local languages that build trust.'),
  _Capability(Icons.biotech_rounded, 'Lab & Radiology',
      'Order diagnostics, receive results and view imaging — fully integrated into the workflow.'),
  _Capability(Icons.verified_user_rounded, 'Insurance & Claims',
      'Automated eligibility checks, pre-authorisation and claims that accelerate reimbursement.'),
  _Capability(Icons.bar_chart_rounded, 'Population Health',
      'Real-time dashboards and predictive analytics that surface disease trends and guide decisions.'),
  _Capability(Icons.api_rounded, 'Open API Platform',
      'A developer-first API layer with usage-based billing so any system can plug into AdhereMed.'),
];

// ═══════════════════════════════════════════════════════════════════════════
//  WELCOME SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late final AnimationController _orbitCtrl;   // radar sweep + packet flow
  late final AnimationController _floatCtrl;   // background blobs
  late final AnimationController _pulseCtrl;   // eyebrow dot pulse

  @override
  void initState() {
    super.initState();
    _orbitCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat(reverse: true);
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbitCtrl.dispose();
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _goLogin() => context.go('/login');
  void _goRegister() => context.go('/register-pharmacy');

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 700;

    return Scaffold(
      backgroundColor: _bgDeep,
      body: Stack(children: [
        // ── Layered background ──
        const _BackgroundBase(),
        const _BackgroundGrid(),
        AnimatedBuilder(
          animation: _floatCtrl,
          builder: (_, __) => CustomPaint(
            size: size,
            painter: _BlobsPainter(t: _floatCtrl.value),
          ),
        ),

        // ── Scrollable content ──
        SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _TopNav(onLogin: _goLogin, onRegister: _goRegister),
              _HeroSection(
                orbitCtrl: _orbitCtrl,
                pulseCtrl: _pulseCtrl,
                isWide: isWide,
                onPrimary: _goRegister,
                onSecondary: _goLogin,
              ),
              const _EcosystemSection(),
              const _CapabilitiesSection(),
              const _NoticeSection(),
              _CtaSection(onPrimary: _goRegister, onSecondary: _goLogin),
              const _FooterSection(),
            ],
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  BACKGROUND
// ═══════════════════════════════════════════════════════════════════════════
class _BackgroundBase extends StatelessWidget {
  const _BackgroundBase();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment(0.6, -1.2),
        end: Alignment(-0.4, 1.2),
        colors: [_bgDeep, _bgMid, _bgEdge],
        stops: [0.0, 0.45, 1.0],
      ),
    ),
    child: const SizedBox.expand(),
  );
}

class _BackgroundGrid extends StatelessWidget {
  const _BackgroundGrid();
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: MediaQuery.of(context).size,
    painter: _GridPainter(),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 0.6;
    const step = 56.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height * 0.55), p);
    }
    for (double y = 0; y < size.height * 0.55; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _BlobsPainter extends CustomPainter {
  final double t;
  _BlobsPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final phase = t * 2 * math.pi;
    final blobs = [
      (Offset(size.width * (0.85 + 0.05 * math.sin(phase)), -60),
          220.0, _bluePrimary.withValues(alpha: 0.32)),
      (Offset(-80, size.height * (0.45 + 0.05 * math.cos(phase))),
          260.0, _blueLight.withValues(alpha: 0.20)),
      (Offset(size.width * 0.78, size.height * (0.30 + 0.04 * math.sin(phase * 0.8))),
          130.0, _blueSoft.withValues(alpha: 0.22)),
    ];
    for (final (pos, r, c) in blobs) {
      final paint = Paint()
        ..color = c
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);
      canvas.drawCircle(pos, r, paint);
    }
  }
  @override
  bool shouldRepaint(covariant _BlobsPainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════════════
//  TOP NAV
// ═══════════════════════════════════════════════════════════════════════════
class _TopNav extends StatelessWidget {
  const _TopNav({required this.onLogin, required this.onRegister});
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
    child: Row(children: [
      const _BrandLockup(small: false),
      const Spacer(),
      _GhostButton(label: 'Sign In', onTap: onLogin),
      const SizedBox(width: 8),
      _PrimaryButton(label: 'Register', onTap: onRegister, dense: true),
    ]),
  ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.3, curve: Curves.easeOut);
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({required this.small});
  final bool small;
  @override
  Widget build(BuildContext context) {
    final badgeSize = small ? 26.0 : 34.0;
    final fontSize = small ? 14.0 : 18.0;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: badgeSize, height: badgeSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_bluePrimary, _blueLight],
          ),
          boxShadow: [BoxShadow(color: _bluePrimary.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 4))],
        ),
        child: Icon(Icons.favorite_rounded, size: small ? 14 : 18, color: Colors.white),
      ),
      const SizedBox(width: 10),
      RichText(text: TextSpan(children: [
        TextSpan(text: 'Adhere',
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
        TextSpan(text: 'Med',
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w300,
            color: Colors.white.withValues(alpha: 0.7), letterSpacing: -0.3)),
      ])),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  HERO
// ═══════════════════════════════════════════════════════════════════════════
class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.orbitCtrl,
    required this.pulseCtrl,
    required this.isWide,
    required this.onPrimary,
    required this.onSecondary,
  });
  final AnimationController orbitCtrl;
  final AnimationController pulseCtrl;
  final bool isWide;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Orbit visual first on narrow screens (mobile)
      Center(
        child: _OrbitVisual(orbitCtrl: orbitCtrl)
          .animate().fadeIn(delay: 250.ms, duration: 700.ms).scale(begin: const Offset(0.85, 0.85)),
      ),
      const SizedBox(height: 28),

      // Eyebrow
      _Eyebrow(pulseCtrl: pulseCtrl)
        .animate().fadeIn(delay: 100.ms, duration: 500.ms).slideX(begin: -0.1),
      const SizedBox(height: 16),

      // Title
      const _HeroTitle()
        .animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.1),
      const SizedBox(height: 16),

      // Subtitle
      Text(
        'AdhereMed unifies patients, doctors, hospitals, pharmacies, labs, radiology, '
        'homecare, insurance and government into a single intelligent platform — '
        'improving medication adherence, care coordination and population health.',
        style: TextStyle(
          fontSize: 14.5,
          height: 1.55,
          color: Colors.white.withValues(alpha: 0.72),
          fontWeight: FontWeight.w400,
        ),
      ).animate().fadeIn(delay: 350.ms, duration: 600.ms),
      const SizedBox(height: 24),

      // CTAs
      Wrap(spacing: 10, runSpacing: 10, children: [
        _PrimaryButton(label: 'Register your Pharmacy', onTap: onPrimary, trailing: Icons.arrow_forward_rounded),
        _GhostButton(label: 'Launch the platform', onTap: onSecondary, large: true),
      ]).animate().fadeIn(delay: 450.ms, duration: 600.ms).slideY(begin: 0.1),
      const SizedBox(height: 28),

      // Stats strip
      const _StatsStrip()
        .animate().fadeIn(delay: 600.ms, duration: 600.ms),
    ]),
  );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.pulseCtrl});
  final AnimationController pulseCtrl;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: _bluePrimary.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: _blueSoft.withValues(alpha: 0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
        animation: pulseCtrl,
        builder: (_, __) {
          final v = pulseCtrl.value;
          return Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: _cyanAccent,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _cyanAccent.withValues(alpha: 0.4 + 0.4 * v), blurRadius: 8 + 6 * v, spreadRadius: 1 + v)],
            ),
          );
        },
      ),
      const SizedBox(width: 8),
      const Text(
        "AFRICA'S HEALTHCARE OPERATING SYSTEM",
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 1.1,
        ),
      ),
    ]),
  );
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle();
  @override
  Widget build(BuildContext context) => RichText(
    text: TextSpan(
      style: const TextStyle(
        fontSize: 38,
        height: 1.1,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: -1.0,
      ),
      children: [
        const TextSpan(text: 'Connected\nHealthcare.\n'),
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [_cyanAccent, _blueSoft, _bluePrimary],
            ).createShader(rect),
            child: const Text(
              'Simplified.',
              style: TextStyle(
                fontSize: 38, height: 1.1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1.0,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: _surfaceAlpha),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: _strokeAlpha)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: _stats.map((s) => Expanded(
        child: Column(children: [
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [_blueSoft, _cyanAccent],
            ).createShader(r),
            child: Text(
              s.value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            s.label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ]),
      )).toList(),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  ORBIT VISUAL  (cloud core + 8 nodes + radar sweep)
// ═══════════════════════════════════════════════════════════════════════════
class _OrbitVisual extends StatelessWidget {
  const _OrbitVisual({required this.orbitCtrl});
  final AnimationController orbitCtrl;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final size = (w * 0.92).clamp(280.0, 380.0);
    return SizedBox(
      width: size, height: size,
      child: AnimatedBuilder(
        animation: orbitCtrl,
        builder: (_, __) => CustomPaint(
          painter: _OrbitPainter(t: orbitCtrl.value, nodeCount: _orbitNodes.length),
          child: Stack(children: [
            // Cloud core
            Center(child: _CloudCore()),
            // Nodes
            for (int i = 0; i < _orbitNodes.length; i++)
              _PositionedNode(
                index: i,
                total: _orbitNodes.length,
                node: _orbitNodes[i],
                size: size,
              ),
          ]),
        ),
      ),
    );
  }
}

class _CloudCore extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 92, height: 92,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const RadialGradient(colors: [Color(0xFF1E40AF), Color(0xFF0B1A3A)]),
      boxShadow: [
        BoxShadow(color: _bluePrimary.withValues(alpha: 0.55), blurRadius: 30, spreadRadius: 2),
        BoxShadow(color: _blueSoft.withValues(alpha: 0.35), blurRadius: 60, spreadRadius: 10),
      ],
      border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.2),
    ),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_rounded, color: Colors.white, size: 28),
        SizedBox(height: 2),
        Text('AdhereMed',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.4)),
        Text('Cloud',
          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w400, color: Colors.white70, letterSpacing: 0.4)),
      ],
    ),
  );
}

class _PositionedNode extends StatelessWidget {
  const _PositionedNode({
    required this.index,
    required this.total,
    required this.node,
    required this.size,
  });
  final int index;
  final int total;
  final _OrbitNode node;
  final double size;

  @override
  Widget build(BuildContext context) {
    final angle = (2 * math.pi / total) * index - math.pi / 2;
    final radius = size * 0.40;
    final cx = size / 2 + radius * math.cos(angle);
    final cy = size / 2 + radius * math.sin(angle);
    const chip = 38.0;
    return Positioned(
      left: cx - chip / 2,
      top: cy - chip / 2 - 8,
      child: Column(children: [
        Container(
          width: chip, height: chip,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF)],
            ),
            boxShadow: [BoxShadow(color: _bluePrimary.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 4))],
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Icon(node.icon, color: Colors.white, size: 17),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _bgMid.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            node.label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ]),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  final double t; // 0..1
  final int nodeCount;
  _OrbitPainter({required this.t, required this.nodeCount});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final rOuter = size.width * 0.40;
    final rInner = size.width * 0.28;

    // Concentric rings
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.1);
    canvas.drawCircle(c, rOuter, ring);
    canvas.drawCircle(c, rInner, ring..color = Colors.white.withValues(alpha: 0.06));

    // 3 expanding radar waves
    for (int i = 0; i < 3; i++) {
      final tt = (t + i / 3) % 1.0;
      final r = rInner * (0.5 + tt * 1.6);
      final alpha = (1.0 - tt) * 0.18;
      canvas.drawCircle(c, r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _cyanAccent.withValues(alpha: alpha));
    }

    // Dotted lines from center to each node
    final line = Paint()
      ..color = _blueSoft.withValues(alpha: 0.28)
      ..strokeWidth = 0.9;
    for (int i = 0; i < nodeCount; i++) {
      final angle = (2 * math.pi / nodeCount) * i - math.pi / 2;
      final end = c + Offset(math.cos(angle), math.sin(angle)) * rOuter;
      _drawDottedLine(canvas, c, end, line);
    }

    // Sweep arc (rotating)
    final sweepAngle = t * 2 * math.pi;
    final rect = Rect.fromCircle(center: c, radius: rOuter);
    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi / 3,
        colors: [_cyanAccent.withValues(alpha: 0), _cyanAccent.withValues(alpha: 0.35)],
        transform: GradientRotation(sweepAngle),
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(sweepAngle);
    canvas.translate(-c.dx, -c.dy);
    final path = Path()
      ..moveTo(c.dx, c.dy)
      ..arcTo(rect, 0, math.pi / 3, false)
      ..close();
    canvas.drawPath(path, sweep);
    canvas.restore();

    // Animated packets travelling between cloud and each node
    final packet = Paint()..color = _cyanAccent;
    for (int i = 0; i < nodeCount; i++) {
      final angle = (2 * math.pi / nodeCount) * i - math.pi / 2;
      final dir = Offset(math.cos(angle), math.sin(angle));
      final start = c + dir * 18;
      final end = c + dir * rOuter;

      // outbound (cloud -> node)
      final tOut = ((t + i / nodeCount) % 1.0);
      final pOut = Offset.lerp(start, end, tOut)!;
      canvas.drawCircle(pOut, 2.2, packet..color = _cyanAccent.withValues(alpha: (1 - tOut) * 0.9));

      // inbound (node -> cloud)
      final tIn = ((t + 0.5 + i / nodeCount) % 1.0);
      final pIn = Offset.lerp(end, start, tIn)!;
      canvas.drawCircle(pIn, 2.0, packet..color = _blueIce.withValues(alpha: (1 - tIn) * 0.85));
    }
  }

  void _drawDottedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0;
    const gap = 4.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    double covered = 0;
    while (covered < total) {
      final s = a + dir * covered;
      final e = a + dir * math.min(covered + dash, total);
      canvas.drawLine(s, e, paint);
      covered += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════════════
//  ECOSYSTEM SECTION
// ═══════════════════════════════════════════════════════════════════════════
class _EcosystemSection extends StatelessWidget {
  const _EcosystemSection();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _SectionHead(
        kicker: 'THE ADHEREMED ECOSYSTEM',
        title: 'Every actor. One intelligent flow.',
        lead:
          'Healthcare is fragmented across disconnected systems. AdhereMed links them into a '
          'single flow — from the patient all the way to population analytics — with secure '
          'data flowing into one unified cloud.',
      ),
      const SizedBox(height: 22),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _actors.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.88,
        ),
        itemBuilder: (_, i) => _ActorCard(index: i, actor: _actors[i])
          .animate().fadeIn(delay: (80 * i).ms, duration: 500.ms).slideY(begin: 0.1),
      ),
    ]),
  );
}

class _ActorCard extends StatelessWidget {
  const _ActorCard({required this.index, required this.actor});
  final int index;
  final _Actor actor;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: _surfaceAlpha),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: _strokeAlpha)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [_bluePrimary, _blueLight],
            ),
            boxShadow: [BoxShadow(color: _bluePrimary.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Icon(actor.icon, color: Colors.white, size: 18),
        ),
        const Spacer(),
        Text(
          (index + 1).toString().padLeft(2, '0'),
          style: TextStyle(fontSize: 11, color: _blueSoft.withValues(alpha: 0.55), fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ]),
      const Spacer(),
      Text(actor.title,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 4),
      Text(actor.desc,
        style: TextStyle(fontSize: 11.5, height: 1.4, color: Colors.white.withValues(alpha: 0.6))),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  CAPABILITIES SECTION
// ═══════════════════════════════════════════════════════════════════════════
class _CapabilitiesSection extends StatelessWidget {
  const _CapabilitiesSection();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 36, 20, 36),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.transparent, _bluePrimary.withValues(alpha: 0.06), Colors.transparent],
      ),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _SectionHead(
        kicker: 'PLATFORM CAPABILITIES',
        title: 'A full healthcare hub in one platform',
        lead:
          'Dashboards, workflows and integrations that simplify healthcare delivery for every '
          'actor in the ecosystem.',
      ),
      const SizedBox(height: 22),
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _capabilities.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _CapabilityCard(cap: _capabilities[i])
          .animate().fadeIn(delay: (60 * i).ms, duration: 500.ms).slideY(begin: 0.08),
      ),
    ]),
  );
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.cap});
  final _Capability cap;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: _surfaceAlpha),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: _strokeAlpha)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_bluePrimary, _blueLight],
          ),
          boxShadow: [BoxShadow(color: _bluePrimary.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: Icon(cap.icon, color: Colors.white, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(cap.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        const SizedBox(height: 4),
        Text(cap.desc,
          style: TextStyle(fontSize: 12.5, height: 1.45, color: Colors.white.withValues(alpha: 0.65))),
      ])),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  NOTICE
// ═══════════════════════════════════════════════════════════════════════════
class _NoticeSection extends StatelessWidget {
  const _NoticeSection();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _blueIce.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _blueIce.withValues(alpha: 0.25)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded, color: _blueIce, size: 22),
        const SizedBox(width: 12),
        Expanded(child: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 12.5, height: 1.5, color: Colors.white.withValues(alpha: 0.82)),
            children: const [
              TextSpan(text: 'Self-registration: ', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
              TextSpan(text: 'Only the '),
              TextSpan(text: 'Pharmacy', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              TextSpan(text: ' module is currently available for self-registration in your jurisdiction. '
                'For hospitals, laboratories, radiology centres or homecare facilities, please contact our team.'),
            ],
          ),
        )),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  CTA
// ═══════════════════════════════════════════════════════════════════════════
class _CtaSection extends StatelessWidget {
  const _CtaSection({required this.onPrimary, required this.onSecondary});
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
    child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0B1A3A), Color(0xFF1E3A8A)],
        ),
        boxShadow: [BoxShadow(color: _bluePrimary.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: 2)],
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(children: [
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(colors: [Colors.white, _cyanAccent]).createShader(r),
          child: const Text(
            'Ready to connect your healthcare?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5, height: 1.2),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Join the platform building Africa's healthcare operating system.",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7), height: 1.5),
        ),
        const SizedBox(height: 20),
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
          _PrimaryButton(label: 'Get started', onTap: onPrimary, trailing: Icons.arrow_forward_rounded),
          _GhostButton(label: 'Sign In', onTap: onSecondary, large: true),
        ]),
      ]),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.05),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  FOOTER
// ═══════════════════════════════════════════════════════════════════════════
class _FooterSection extends StatelessWidget {
  const _FooterSection();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
    child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const _BrandLockup(small: true),
      const SizedBox(height: 10),
      Text(
        '© 2026 AdhereMed. Connected Healthcare. Simplified.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.35)),
      ),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════
class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.kicker, required this.title, required this.lead});
  final String kicker, title, lead;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _bluePrimary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: _blueSoft.withValues(alpha: 0.25)),
        ),
        child: Text(kicker,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _blueIce, letterSpacing: 1.2)),
      ),
      const SizedBox(height: 12),
      Text(title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white,
          letterSpacing: -0.5, height: 1.2,
        )),
      const SizedBox(height: 10),
      Text(lead,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.62), height: 1.55)),
    ],
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap, this.trailing, this.dense = false});
  final String label;
  final VoidCallback onTap;
  final IconData? trailing;
  final bool dense;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 18, vertical: dense ? 10 : 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_bluePrimary, _blueLight],
          ),
          boxShadow: [BoxShadow(color: _bluePrimary.withValues(alpha: 0.5), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
            style: TextStyle(color: Colors.white, fontSize: dense ? 12.5 : 14, fontWeight: FontWeight.w700)),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Icon(trailing, color: Colors.white, size: dense ? 14 : 16),
          ],
        ]),
      ),
    ),
  );
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap, this.large = false});
  final String label;
  final VoidCallback onTap;
  final bool large;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: large ? 18 : 12, vertical: large ? 14 : 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Text(label,
          style: TextStyle(
            color: Colors.white,
            fontSize: large ? 14 : 12.5,
            fontWeight: FontWeight.w600,
          )),
      ),
    ),
  );
}

// `AppLocalizations` referenced indirectly to satisfy the import (sign-in label
// remains hardcoded in this landing-page screen to match the Nuxt copy exactly).
// ignore: unused_element
String _signInFallback(BuildContext context) =>
    AppLocalizations.of(context)?.signIn ?? 'Sign In';
