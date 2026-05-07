// ignore_for_file: deprecated_member_use

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nationalIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    await ref.read(authProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: _phoneController.text.trim(),
          nationalId: _nationalIdController.text.trim(),
        );

    final state = ref.read(authProvider);
    if (state.hasError && mounted) {
      final error = state.error;
      String message = 'Registration failed. Please try again.';
      if (error is DioException) {
        final data = error.response?.data;
        if (data is Map) {
          final errors = data.entries
              .map((e) =>
                  e.value is List ? (e.value as List).join(', ') : '${e.value}')
              .join('\n');
          if (errors.isNotEmpty) message = errors;
        }
      }
      setState(() => _errorMessage = message);
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
          // ── Brand gradient ──
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
            right: -80,
            child: _Circle(260, Colors.white.withOpacity(0.05)),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: _Circle(300, Colors.white.withOpacity(0.04)),
          ),
          // ── Content ──
          SafeArea(
            child: isWide
                ? _WideLayout(
                    formKey: _formKey,
                    firstNameController: _firstNameController,
                    lastNameController: _lastNameController,
                    emailController: _emailController,
                    phoneController: _phoneController,
                    nationalIdController: _nationalIdController,
                    passwordController: _passwordController,
                    confirmPasswordController: _confirmPasswordController,
                    obscurePassword: _obscurePassword,
                    onToggleObscure: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    errorMessage: _errorMessage,
                    isLoading: isLoading,
                    onRegister: _handleRegister,
                  )
                : _NarrowLayout(
                    formKey: _formKey,
                    firstNameController: _firstNameController,
                    lastNameController: _lastNameController,
                    emailController: _emailController,
                    phoneController: _phoneController,
                    nationalIdController: _nationalIdController,
                    passwordController: _passwordController,
                    confirmPasswordController: _confirmPasswordController,
                    obscurePassword: _obscurePassword,
                    onToggleObscure: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    errorMessage: _errorMessage,
                    isLoading: isLoading,
                    onRegister: _handleRegister,
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
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.phoneController,
    required this.nationalIdController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.errorMessage,
    required this.isLoading,
    required this.onRegister,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController nationalIdController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left brand panel
        SizedBox(
          width: 280,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BackButton(),
                const SizedBox(height: 48),
                _LogoMark(),
                const SizedBox(height: 24),
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Adhere',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                      TextSpan(
                        text: 'Med',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w300,
                          color: Color(0xFF5EEAD4),
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your personal health\ncompanion.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.65),
                    height: 1.55,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 36),
                ...[
                  (Icons.calendar_month_rounded, 'Book Appointments'),
                  (Icons.favorite_rounded, 'Track Your Health'),
                  (Icons.local_pharmacy_rounded, 'Order Medicines'),
                  (Icons.chat_bubble_outline_rounded, 'Chat with Doctors'),
                ].map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.12),
                          ),
                          child: Icon(b.$1,
                              color: const Color(0xFF99F6E4), size: 16),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          b.$2,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
            child: Center(
              child: _FormCard(
                formKey: formKey,
                firstNameController: firstNameController,
                lastNameController: lastNameController,
                emailController: emailController,
                phoneController: phoneController,
                nationalIdController: nationalIdController,
                passwordController: passwordController,
                confirmPasswordController: confirmPasswordController,
                obscurePassword: obscurePassword,
                onToggleObscure: onToggleObscure,
                errorMessage: errorMessage,
                isLoading: isLoading,
                onRegister: onRegister,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.formKey,
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.phoneController,
    required this.nationalIdController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.errorMessage,
    required this.isLoading,
    required this.onRegister,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController nationalIdController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          _BackButton(),
          const SizedBox(height: 24),
          _LogoMark(),
          const SizedBox(height: 14),
          RichText(
            textAlign: TextAlign.center,
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Adhere',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
                TextSpan(
                  text: 'Med',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFF5EEAD4)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _FormCard(
            formKey: formKey,
            firstNameController: firstNameController,
            lastNameController: lastNameController,
            emailController: emailController,
            phoneController: phoneController,
            nationalIdController: nationalIdController,
            passwordController: passwordController,
            confirmPasswordController: confirmPasswordController,
            obscurePassword: obscurePassword,
            onToggleObscure: onToggleObscure,
            errorMessage: errorMessage,
            isLoading: isLoading,
            onRegister: onRegister,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Shared UI ────────────────────────────────────────────────────────────────

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.15),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CustomPaint(painter: _CrossPainter()),
        ),
      ),
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
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, (h - t) / 2, w, t), Radius.circular(t / 2)),
      p,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH((w - t) / 2, 0, t, h), Radius.circular(t / 2)),
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
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.phoneController,
    required this.nationalIdController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.errorMessage,
    required this.isLoading,
    required this.onRegister,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController nationalIdController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 480,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withOpacity(0.10),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
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
              'Create your account',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Join AdhereMed to manage your health',
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withOpacity(0.6)),
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
              const SizedBox(height: 24),
            ],

            // Name row
            Row(
              children: [
                Expanded(
                  child: _GlassField(
                    controller: firstNameController,
                    label: 'First Name',
                    icon: Icons.person_outline_rounded,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GlassField(
                    controller: lastNameController,
                    label: 'Last Name',
                    icon: Icons.person_outline_rounded,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

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

            _GlassField(
              controller: phoneController,
              label: 'Phone (optional)',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),

            _GlassField(
              controller: nationalIdController,
              label: 'National ID',
              icon: Icons.badge_outlined,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'National ID is required' : null,
            ),
            const SizedBox(height: 14),

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
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 8) return 'Minimum 8 characters';
                return null;
              },
            ),
            const SizedBox(height: 14),

            _GlassField(
              controller: confirmPasswordController,
              label: 'Confirm Password',
              icon: Icons.lock_outline_rounded,
              obscureText: obscurePassword,
              validator: (v) {
                if (v != passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),

            const SizedBox(height: 28),

            // Submit
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading ? null : onRegister,
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
                    : const Text('Create Account'),
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
                  child: Text('or',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4), fontSize: 12)),
                ),
                Expanded(
                    child: Divider(color: Colors.white.withOpacity(0.15))),
              ],
            ),

            const SizedBox(height: 20),

            _LinkRow(
              label: 'Already have an account?',
              actionLabel: 'Sign In',
              onTap: () => context.go('/login'),
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
        labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.55), fontSize: 14),
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
          borderSide: const BorderSide(color: Color(0xFFFCA5A5)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
        ),
        errorStyle:
            const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
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
