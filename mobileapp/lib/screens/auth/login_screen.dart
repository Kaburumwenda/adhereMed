import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  NETWORK NODE + PAINTER (same as welcome, shared background)
// ═══════════════════════════════════════════════════════════════════════════
class _NetNode {
  Offset pos;
  Offset velocity;
  final double radius;
  final Color color;
  _NetNode({required this.pos, required this.velocity, required this.radius, required this.color});
}

class _NetworkPainter extends CustomPainter {
  final List<_NetNode> nodes;
  final double connectDist;
  final double pulse;
  _NetworkPainter(this.nodes, {this.connectDist = 160, this.pulse = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..strokeWidth = 0.8;
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        final d = (nodes[i].pos - nodes[j].pos).distance;
        if (d < connectDist) {
          linePaint.color = Colors.white.withValues(alpha: (1 - d / connectDist) * 0.25);
          canvas.drawLine(nodes[i].pos, nodes[j].pos, linePaint);
        }
      }
    }
    for (final n in nodes) {
      canvas.drawCircle(n.pos, n.radius + 8,
          Paint()..color = n.color.withValues(alpha: 0.12 + pulse * 0.06)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      canvas.drawCircle(n.pos, n.radius, Paint()..color = n.color.withValues(alpha: 0.18 + pulse * 0.06));
      canvas.drawCircle(n.pos, n.radius,
          Paint()..color = n.color.withValues(alpha: 0.35)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    }
  }

  @override
  bool shouldRepaint(covariant _NetworkPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════════════
//  LOGIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  // Network animation
  late final AnimationController _netCtrl;
  late final AnimationController _pulseCtrl;
  final List<_NetNode> _nodes = [];
  final _rng = Random(77);
  bool _nodesInit = false;

  static const _nodeColors = [
    Color(0xFF5EEAD4), Color(0xFF7DD3FC), Color(0xFFF9A8D4),
    Color(0xFFC4B5FD), Color(0xFFFBBF24), Color(0xFFA7F3D0),
    Color(0xFFFCA5A5), Color(0xFF93C5FD), Color(0xFF86EFAC),
    Color(0xFFFDE68A),
  ];

  @override
  void initState() {
    super.initState();
    _netCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 50))
      ..addListener(_tick)..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
  }

  void _initNodes(Size size) {
    if (_nodesInit) return;
    _nodesInit = true;
    for (var i = 0; i < _nodeColors.length; i++) {
      _nodes.add(_NetNode(
        pos: Offset(_rng.nextDouble() * size.width, _rng.nextDouble() * size.height),
        velocity: Offset((_rng.nextDouble() - 0.5) * 0.5, (_rng.nextDouble() - 0.5) * 0.5),
        radius: 12 + _rng.nextDouble() * 8,
        color: _nodeColors[i],
      ));
    }
  }

  void _tick() {
    if (!mounted || _nodes.isEmpty) return;
    final sz = MediaQuery.of(context).size;
    for (final n in _nodes) {
      n.pos += n.velocity;
      if (n.pos.dx < -20 || n.pos.dx > sz.width + 20) n.velocity = Offset(-n.velocity.dx, n.velocity.dy);
      if (n.pos.dy < -20 || n.pos.dy > sz.height + 20) n.velocity = Offset(n.velocity.dx, -n.velocity.dy);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _netCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).login(_emailCtrl.text.trim(), _passCtrl.text);
    if (ok && mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;
    _initNodes(size);

    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF115E59), Color(0xFF134E4A)],
                stops: [0.0, 0.35, 0.7, 1.0],
              ),
            ),
          ),

          // Network animation
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _NetworkPainter(_nodes, connectDist: 170, pulse: _pulseCtrl.value),
            ),
          ),

          // Form content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Image.asset('assets/images/logo_nobg.png', width: 40, height: 40, fit: BoxFit.contain),
                        ),
                        const SizedBox(height: 16),
                        Text('AdhereMed', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('Sign in to your account', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                        const SizedBox(height: 28),

                        if (auth.error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
                            child: Text(auth.error!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                          const SizedBox(height: 16),
                        ],

                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                            prefixIcon: Icon(Icons.email_outlined, color: Colors.white.withValues(alpha: 0.7)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white, width: 2)),
                            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.shade200)),
                            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.shade200, width: 2)),
                          ),
                          validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                            prefixIcon: Icon(Icons.lock_outline, color: Colors.white.withValues(alpha: 0.7)),
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white.withValues(alpha: 0.7)),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white, width: 2)),
                            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.shade200)),
                            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.red.shade200, width: 2)),
                          ),
                          validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: auth.loading ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0F766E),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: auth.loading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)))
                                : const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
