import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  NETWORK NODE MODEL
// ═══════════════════════════════════════════════════════════════════════════
class _NetNode {
  Offset pos;
  Offset velocity;
  final double radius;
  final IconData icon;
  final Color color;

  _NetNode({
    required this.pos,
    required this.velocity,
    required this.radius,
    required this.icon,
    required this.color,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
//  NETWORK PAINTER — draws nodes + connecting lines
// ═══════════════════════════════════════════════════════════════════════════
class _NetworkPainter extends CustomPainter {
  final List<_NetNode> nodes;
  final double connectDist;
  final double pulse; // 0‥1

  _NetworkPainter(this.nodes, {this.connectDist = 160, this.pulse = 0});

  @override
  void paint(Canvas canvas, Size size) {
    // draw connections
    final linePaint = Paint()..strokeWidth = 0.8;
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        final d = (nodes[i].pos - nodes[j].pos).distance;
        if (d < connectDist) {
          final opacity = (1 - d / connectDist) * 0.25;
          linePaint.color = Colors.white.withValues(alpha: opacity);
          canvas.drawLine(nodes[i].pos, nodes[j].pos, linePaint);
        }
      }
    }

    // draw node circles
    for (final n in nodes) {
      final glow = Paint()
        ..color = n.color.withValues(alpha: 0.12 + pulse * 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(n.pos, n.radius + 8, glow);

      final fill = Paint()..color = n.color.withValues(alpha: 0.18 + pulse * 0.06);
      canvas.drawCircle(n.pos, n.radius, fill);

      final border = Paint()
        ..color = n.color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(n.pos, n.radius, border);
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════
//  WELCOME SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _netCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _splitCtrl;
  late final Animation<double> _splitAnim;
  final List<_NetNode> _nodes = [];
  final _rng = Random(42);
  bool _nodesInit = false;
  bool _splitting = false;

  static const _nodeData = [
    (Icons.local_hospital_rounded, Color(0xFF5EEAD4)),
    (Icons.local_pharmacy_rounded, Color(0xFF7DD3FC)),
    (Icons.science_rounded, Color(0xFFF9A8D4)),
    (Icons.monitor_heart_rounded, Color(0xFFC4B5FD)),
    (Icons.person_rounded, Color(0xFFFBBF24)),
    (Icons.home_rounded, Color(0xFFA7F3D0)),
    (Icons.vaccines_rounded, Color(0xFFFCA5A5)),
    (Icons.biotech_rounded, Color(0xFF93C5FD)),
    (Icons.health_and_safety_rounded, Color(0xFF86EFAC)),
    (Icons.medical_services_rounded, Color(0xFFFDE68A)),
    (Icons.medication_rounded, Color(0xFFD8B4FE)),
    (Icons.healing_rounded, Color(0xFF67E8F9)),
  ];

  @override
  void initState() {
    super.initState();
    _netCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..addListener(_tick)..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _splitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _splitAnim = CurvedAnimation(parent: _splitCtrl, curve: Curves.easeInBack);
  }

  void _navigateToLogin() {
    if (_splitting) return;
    _splitting = true;
    setState(() {});
    _splitCtrl.forward().then((_) {
      if (mounted) context.go('/login');
    });
  }

  void _initNodes(Size size) {
    if (_nodesInit) return;
    _nodesInit = true;
    for (var i = 0; i < _nodeData.length; i++) {
      final (icon, color) = _nodeData[i];
      _nodes.add(_NetNode(
        pos: Offset(
          _rng.nextDouble() * size.width,
          _rng.nextDouble() * size.height,
        ),
        velocity: Offset(
          (_rng.nextDouble() - 0.5) * 0.6,
          (_rng.nextDouble() - 0.5) * 0.6,
        ),
        radius: 14 + _rng.nextDouble() * 8,
        icon: icon,
        color: color,
      ));
    }
  }

  void _tick() {
    if (!mounted || _nodes.isEmpty) return;
    final sz = MediaQuery.of(context).size;
    for (final n in _nodes) {
      n.pos += n.velocity;
      if (n.pos.dx < -20 || n.pos.dx > sz.width + 20) {
        n.velocity = Offset(-n.velocity.dx, n.velocity.dy);
      }
      if (n.pos.dy < -20 || n.pos.dy > sz.height + 20) {
        n.velocity = Offset(n.velocity.dx, -n.velocity.dy);
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _netCtrl.dispose();
    _pulseCtrl.dispose();
    _splitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _initNodes(size);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _splitAnim,
        builder: (_, __) {
          final t = _splitAnim.value;
          final halfH = size.height / 2;

          return Stack(
            children: [
              // ── Reveal layer (dark bg behind the split) ──
              if (t > 0)
                Container(
                  color: const Color(0xFF0F172A),
                  child: Center(
                    child: Opacity(
                      opacity: t,
                      child: const Icon(Icons.lock_open_rounded,
                          size: 48, color: Color(0xFF5EEAD4)),
                    ),
                  ),
                ),

              // ── Top half ──
              Transform.translate(
                offset: Offset(0, -halfH * t),
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: 0.5,
                    child: _buildBody(size),
                  ),
                ),
              ),

              // ── Bottom half ──
              Transform.translate(
                offset: Offset(0, halfH * t),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      heightFactor: 0.5,
                      child: _buildBody(size),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(Size size) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        children: [
          // ── Gradient Background ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F766E),
                  Color(0xFF0D9488),
                  Color(0xFF115E59),
                  Color(0xFF134E4A),
                ],
                stops: [0.0, 0.35, 0.7, 1.0],
              ),
            ),
          ),

          // ── Animated Network Background ──
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _NetworkPainter(
                _nodes,
                connectDist: 170,
                pulse: _pulseCtrl.value,
              ),
            ),
          ),

          // ── Content ──
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),

                // ── Top Bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white.withValues(alpha: 0.15),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/logo_nobg.png',
                            width: 28,
                            height: 28,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'AdhereMed',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _navigateToLogin,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Sign In',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: -0.3, curve: Curves.easeOut),

                // ── Hero Section ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        SizedBox(height: size.height * 0.05),

                        // Logo image
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.1),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                                width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF5EEAD4).withValues(alpha: 0.15),
                                blurRadius: 40,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                            child: Image.asset(
                              'assets/images/logo_nobg.png',
                              width: 72,
                              height: 72,
                              fit: BoxFit.contain,
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 600.ms)
                            .scale(begin: const Offset(0.6, 0.6)),

                        const SizedBox(height: 28),

                        // Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Adhere',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const Text(
                              'Med',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w300,
                                color: Color(0xFF5EEAD4),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        )
                            .animate()
                            .fadeIn(delay: 400.ms, duration: 600.ms)
                            .slideY(begin: 0.2),

                        const SizedBox(height: 10),

                        // Tagline
                        Text(
                          'Connected Healthcare.\nSimplified.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w300,
                            color: Colors.white.withValues(alpha: 0.85),
                            height: 1.4,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 600.ms, duration: 600.ms),

                        const SizedBox(height: 36),

                        // ── Feature Cards Grid ──
                        _buildFeatureGrid()
                            .animate()
                            .fadeIn(delay: 800.ms, duration: 700.ms)
                            .slideY(begin: 0.15),

                        const SizedBox(height: 32),

                        // ── Footer ──
                        Text(
                          '© 2026 AdhereMed · Powering Healthcare Excellence',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid() {
    const features = [
      _Feature(Icons.local_hospital_rounded, 'Hospitals',
          'Patients, consultations,\nbilling & more', Color(0xFF5EEAD4)),
      _Feature(Icons.local_pharmacy_rounded, 'Pharmacies',
          'POS, inventory, dispensing\n& analytics', Color(0xFF7DD3FC)),
      _Feature(Icons.science_rounded, 'Laboratories',
          'Lab orders, results\n& exchange', Color(0xFFF9A8D4)),
      _Feature(Icons.monitor_heart_rounded, 'Radiology',
          'Imaging orders, reports\n& scheduling', Color(0xFFC4B5FD)),
      _Feature(Icons.person_rounded, 'Patients',
          'Records, prescriptions\n& online orders', Color(0xFFFBBF24)),
      _Feature(Icons.home_rounded, 'Homecare',
          'In-home visits, care\nplans & monitoring', Color(0xFFA7F3D0)),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: features.asMap().entries.map((e) {
        final i = e.key;
        final f = e.value;
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 60) / 2,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: f.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(f.icon, color: f.color, size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  f.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  f.desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(delay: (900 + i * 80).ms, duration: 400.ms)
              .slideY(begin: 0.15),
        );
      }).toList(),
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  const _Feature(this.icon, this.title, this.desc, this.color);
}
