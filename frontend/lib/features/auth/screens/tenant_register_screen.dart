// ignore_for_file: deprecated_member_use

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';

class TenantRegisterScreen extends StatefulWidget {
  const TenantRegisterScreen({super.key});

  @override
  State<TenantRegisterScreen> createState() => _TenantRegisterScreenState();
}

class _TenantRegisterScreenState extends State<TenantRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _selectedType;

  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _orgPhoneController = TextEditingController();
  final _orgEmailController = TextEditingController();
  final _adminFirstNameController = TextEditingController();
  final _adminLastNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _orgPhoneController.dispose();
    _orgEmailController.dispose();
    _adminFirstNameController.dispose();
    _adminLastNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _generateSlug(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'[\s]+'), '-');
  }

  Future<void> _handleSubmit() async {
    if (_selectedType == null) {
      setState(() => _errorMessage = 'Please select a facility type.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final slug = _slugController.text.trim();
      await ApiClient.instance.post('/tenants/register/', data: {
        'name': _nameController.text.trim(),
        'type': _selectedType,
        'slug': slug,
        'domain': '$slug.localhost',
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'phone': _orgPhoneController.text.trim(),
        'email': _orgEmailController.text.trim(),
        'admin_email': _adminEmailController.text.trim(),
        'admin_first_name': _adminFirstNameController.text.trim(),
        'admin_last_name': _adminLastNameController.text.trim(),
        'admin_password': _adminPasswordController.text,
      });

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.check_circle_rounded,
              color: Color(0xFF22C55E), size: 52),
          title: const Text('Registration Successful!',
              textAlign: TextAlign.center),
          content: Text(
            'Your ${_selectedType == "hospital" ? "hospital" : "pharmacy"} '
            '"${_nameController.text.trim()}" has been created.\n\n'
            'You can now log in with your admin credentials.',
            textAlign: TextAlign.center,
          ),
          actions: [
            Center(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(160, 48),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/login');
                },
                child: const Text('Go to Login'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      String message = 'Registration failed. Please try again.';
      if (data is Map) {
        final errors = data.entries
            .map((e) =>
                e.value is List ? (e.value as List).join(', ') : '${e.value}')
            .join('\n');
        if (errors.isNotEmpty) message = errors;
      }
      setState(() => _errorMessage = message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width > 860;

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
            child: _Circle(280, Colors.white.withOpacity(0.05)),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: _Circle(320, Colors.white.withOpacity(0.04)),
          ),

          // ── Content ──
          SafeArea(
            child: isWide
                ? _wideLayout(context)
                : _narrowLayout(context),
          ),
        ],
      ),
    );
  }

  Widget _wideLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: brand panel
        SizedBox(
          width: 300,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
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
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                      TextSpan(
                        text: 'Med',
                        style: TextStyle(
                          fontSize: 34,
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
                  'Register your facility and\ngo live in minutes.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.5,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 40),
                ...[
                  (Icons.local_hospital_rounded, 'Hospital & Ward Mgmt'),
                  (Icons.medical_services_rounded, 'Pharmacy & Dispensing'),
                  (Icons.people_alt_rounded, 'Patient Records'),
                  (Icons.shield_rounded, 'Insurance & Billing'),
                ].map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.12),
                          ),
                          child: Icon(b.$1,
                              color: const Color(0xFF99F6E4), size: 17),
                        ),
                        const SizedBox(width: 12),
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

        // Right: scrollable form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 32),
            child: Center(child: _formCard(context)),
          ),
        ),
      ],
    );
  }

  Widget _narrowLayout(BuildContext context) {
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
          _formCard(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _formCard(BuildContext context) {
    return Container(
      width: 560,
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
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Text(
              'Register Your Facility',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Set up a hospital or pharmacy on AdhereMed',
              style:
                  TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6)),
            ),

            const SizedBox(height: 28),

            // Error banner
            if (_errorMessage != null) ...[
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
                        _errorMessage!,
                        style: const TextStyle(
                            color: Color(0xFFFCA5A5), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ─── Facility Type ───
            _sectionLabel('Facility Type'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: _typeChip('hospital', Icons.local_hospital_rounded,
                        'Hospital')),
                const SizedBox(width: 12),
                Expanded(
                    child: _typeChip('pharmacy', Icons.local_pharmacy_rounded,
                        'Pharmacy')),
              ],
            ),

            const SizedBox(height: 28),

            // ─── Organisation Info ───
            _sectionLabel('Organisation Info'),
            const SizedBox(height: 12),
            _GlassField(
              controller: _nameController,
              label: 'Facility Name',
              icon: Icons.business_rounded,
              onChanged: (v) => _slugController.text = _generateSlug(v),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Facility name is required' : null,
            ),
            const SizedBox(height: 12),
            _GlassField(
              controller: _slugController,
              label: 'URL Identifier',
              icon: Icons.link_rounded,
              helperText: 'Auto-generated · lowercase, numbers, hyphens',
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(v)) {
                  return 'Lowercase letters, numbers, hyphens only';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _GlassField(
                    controller: _orgEmailController,
                    label: 'Organisation Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GlassField(
                    controller: _orgPhoneController,
                    label: 'Phone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _GlassField(
              controller: _cityController,
              label: 'City',
              icon: Icons.location_city_rounded,
            ),

            const SizedBox(height: 28),

            // ─── Admin Account ───
            _sectionLabel('Admin Account'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _GlassField(
                    controller: _adminFirstNameController,
                    label: 'First Name',
                    icon: Icons.person_outline_rounded,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GlassField(
                    controller: _adminLastNameController,
                    label: 'Last Name',
                    icon: Icons.person_outline_rounded,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _GlassField(
              controller: _adminEmailController,
              label: 'Admin Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              helperText: 'This will be your login email',
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (!v.contains('@')) return 'Invalid email';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _GlassField(
              controller: _adminPasswordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.white54,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 8) return 'Minimum 8 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _GlassField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              validator: (v) {
                if (v != _adminPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Submit
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
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
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF0F766E),
                        ),
                      )
                    : const Text('Register Facility'),
              ),
            ),

            const SizedBox(height: 24),

            // Sign in link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already registered? ',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 13),
                ),
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(
                      color: Color(0xFF5EEAD4),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF5EEAD4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF5EEAD4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: Color(0xFF99F6E4),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _typeChip(String value, IconData icon, String label) {
    final selected = _selectedType == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? Colors.white.withOpacity(0.18)
              : Colors.white.withOpacity(0.07),
          border: Border.all(
            color: selected
                ? const Color(0xFF5EEAD4)
                : Colors.white.withOpacity(0.2),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 30,
              color: selected
                  ? const Color(0xFF99F6E4)
                  : Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w400,
                color: selected
                    ? Colors.white
                    : Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

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

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.helperText,
    this.onChanged,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? helperText;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      cursorColor: const Color(0xFF5EEAD4),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.55), fontSize: 14),
        floatingLabelStyle:
            const TextStyle(color: Color(0xFF5EEAD4), fontSize: 13),
        helperText: helperText,
        helperStyle:
            TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
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
