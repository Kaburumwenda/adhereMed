// ignore_for_file: deprecated_member_use

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _errorMessage = null);

    await ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );

    final state = ref.read(authProvider);
    if (state.hasError && mounted) {
      final error = state.error;
      String message = 'Login failed. Please try again.';
      if (error is DioException) {
        final statusCode = error.response?.statusCode;
        if (statusCode == 400 || statusCode == 401) {
          message = 'Invalid email or password.';
        } else if (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.connectionTimeout) {
          message = 'Cannot connect to server.';
        }
      }
      setState(() => _errorMessage = message);
    } else if (!state.hasError && state.valueOrNull != null && mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width > 800;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Brand gradient (matches welcome screen) ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.45, 0.75, 1.0],
                colors: [
                  Color(0xFF064E3B),
                  Color(0xFF0F766E),
                  Color(0xFF1D4ED8),
                  Color(0xFF312E81),
                ],
              ),
            ),
          ),

          // ── Decorative blobs ──
          Positioned(
            top: -80,
            left: -80,
            child: _Circle(240, Colors.white.withOpacity(0.05)),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: _Circle(300, Colors.white.withOpacity(0.05)),
          ),

          // ── Content ──
          SafeArea(
            child: isWide
                ? _WideLayout(
                    formKey: _formKey,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    obscurePassword: _obscurePassword,
                    onToggleObscure: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    errorMessage: _errorMessage,
                    isLoading: isLoading,
                    onLogin: _handleLogin,
                  )
                : _NarrowLayout(
                    formKey: _formKey,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    obscurePassword: _obscurePassword,
                    onToggleObscure: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    errorMessage: _errorMessage,
                    isLoading: isLoading,
                    onLogin: _handleLogin,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Layout helpers ───────────────────────────────────────────────────────────

class _Circle extends StatelessWidget {
  const _Circle(this.size, this.color);
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.errorMessage,
    required this.isLoading,
    required this.onLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left: branding panel
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back
                _BackButton(),
                const SizedBox(height: 48),
                // Logo mark
                _LogoMark(),
                const SizedBox(height: 32),
                // Headline
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Adhere',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      TextSpan(
                        text: 'Med',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w300,
                          color: Color(0xFF5EEAD4),
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Connected Healthcare.\nSimplified.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withOpacity(0.75),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                ..._bullets.map((b) => _BulletRow(b)),
              ],
            ),
          ),
        ),

        // Right: form card
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 40),
            child: _FormCard(
              formKey: formKey,
              emailController: emailController,
              passwordController: passwordController,
              obscurePassword: obscurePassword,
              onToggleObscure: onToggleObscure,
              errorMessage: errorMessage,
              isLoading: isLoading,
              onLogin: onLogin,
            ),
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.errorMessage,
    required this.isLoading,
    required this.onLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          _BackButton(),
          const SizedBox(height: 32),
          _LogoMark(),
          const SizedBox(height: 16),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Adhere',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                TextSpan(
                  text: 'Med',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    color: Color(0xFF5EEAD4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _FormCard(
            formKey: formKey,
            emailController: emailController,
            passwordController: passwordController,
            obscurePassword: obscurePassword,
            onToggleObscure: onToggleObscure,
            errorMessage: errorMessage,
            isLoading: isLoading,
            onLogin: onLogin,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

const _bullets = [
  (Icons.local_hospital_rounded, 'Hospital & Ward Management'),
  (Icons.medical_services_rounded, 'Pharmacy & Dispensing'),
  (Icons.shield_rounded, 'Insurance & Billing'),
  (Icons.biotech_rounded, 'Lab & Radiology'),
];

class _BulletRow extends StatelessWidget {
  const _BulletRow(this.data);
  final (IconData, String) data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.12),
            ),
            child: Icon(data.$1, color: const Color(0xFF99F6E4), size: 18),
          ),
          const SizedBox(width: 14),
          Text(
            data.$2,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.15),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: const Center(
        child: _CrossIcon(),
      ),
    );
  }
}

class _CrossIcon extends StatelessWidget {
  const _CrossIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: CustomPaint(painter: _CrossPainter()),
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final t = w * 0.28;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, (h - t) / 2, w, t),
          Radius.circular(t / 2)),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH((w - t) / 2, 0, t, h),
          Radius.circular(t / 2)),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/welcome'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white.withOpacity(0.7), size: 14),
          const SizedBox(width: 4),
          Text(
            'Back',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Form Card ────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.errorMessage,
    required this.isLoading,
    required this.onLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.10),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(36),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Text(
              'Welcome back',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to your account to continue',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.6),
              ),
            ),

            const SizedBox(height: 28),

            // Error banner
            if (errorMessage != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFFCA5A5), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                            color: Color(0xFFFCA5A5), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Email field
            _GlassField(
              controller: emailController,
              label: 'Email address',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),

            const SizedBox(height: 14),

            // Password field
            _GlassField(
              controller: passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              obscureText: obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.white54,
                  size: 20,
                ),
                onPressed: onToggleObscure,
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Password is required' : null,
            ),

            const SizedBox(height: 8),

            // Forgot password
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => context.go('/forgot-password'),
                child: Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF5EEAD4).withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Sign In button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F766E),
                  disabledBackgroundColor: Colors.white38,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF0F766E),
                        ),
                      )
                    : const Text('Sign In'),
              ),
            ),

            const SizedBox(height: 28),

            // Divider
            Row(
              children: [
                Expanded(
                    child: Divider(color: Colors.white.withOpacity(0.15))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 12),
                  ),
                ),
                Expanded(
                    child: Divider(color: Colors.white.withOpacity(0.15))),
              ],
            ),

            const SizedBox(height: 20),

            // Register links
            _LinkRow(
              label: "Don't have an account?",
              actionLabel: 'Sign up',
              onTap: () => context.go('/register'),
            ),
            const SizedBox(height: 8),
            _LinkRow(
              label: 'Registering a facility?',
              actionLabel: 'Register Facility',
              onTap: () => context.go('/register-facility'),
            ),
            const SizedBox(height: 8),
            _LinkRow(
              label: 'Are you a doctor?',
              actionLabel: 'Doctor Sign Up',
              onTap: () => context.go('/register-doctor'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: const Color(0xFF5EEAD4),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14),
        floatingLabelStyle:
            const TextStyle(color: Color(0xFF5EEAD4), fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFF5EEAD4), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFFCA5A5), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.label,
    required this.actionLabel,
    required this.onTap,
  });

  final String label;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$label ',
          style:
              TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            actionLabel,
            style: const TextStyle(
              color: Color(0xFF5EEAD4),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              decorationColor: Color(0xFF5EEAD4),
            ),
          ),
        ),
      ],
    );
  }
}
