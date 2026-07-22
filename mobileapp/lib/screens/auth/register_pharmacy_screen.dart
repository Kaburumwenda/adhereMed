import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  COLOR TOKENS — mirrors nuxtfrontend/pages/register-pharmacy.vue
// ═══════════════════════════════════════════════════════════════════════════
const _bgDeep = Color(0xFF060B18);
const _bgMid = Color(0xFF081226);
const _bgEdge = Color(0xFF0A1530);
const _bluePrimary = Color(0xFF2563EB);
const _blueDark = Color(0xFF1D4ED8);
const _blueLight = Color(0xFF3B82F6);
const _blueSoft = Color(0xFF60A5FA);
const _blueIce = Color(0xFF93C5FD);

// ═══════════════════════════════════════════════════════════════════════════
//  COUNTRIES
// ═══════════════════════════════════════════════════════════════════════════
class _Country {
  final String name;
  final String code;
  const _Country(this.name, this.code);
}

const _countries = <_Country>[
  _Country('Kenya', 'KE'),
  _Country('Uganda', 'UG'),
  _Country('Tanzania', 'TZ'),
  _Country('Rwanda', 'RW'),
  _Country('Ethiopia', 'ET'),
  _Country('Nigeria', 'NG'),
  _Country('Ghana', 'GH'),
  _Country('South Africa', 'ZA'),
  _Country('Egypt', 'EG'),
  _Country('Morocco', 'MA'),
  _Country('United States', 'US'),
  _Country('United Kingdom', 'GB'),
  _Country('Canada', 'CA'),
  _Country('Germany', 'DE'),
  _Country('France', 'FR'),
  _Country('India', 'IN'),
  _Country('United Arab Emirates', 'AE'),
  _Country('Saudi Arabia', 'SA'),
  _Country('Australia', 'AU'),
  _Country('Brazil', 'BR'),
];

// ═══════════════════════════════════════════════════════════════════════════
//  REGISTER PHARMACY SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class RegisterPharmacyScreen extends ConsumerStatefulWidget {
  const RegisterPharmacyScreen({super.key});
  @override
  ConsumerState<RegisterPharmacyScreen> createState() =>
      _RegisterPharmacyScreenState();
}

class _RegisterPharmacyScreenState
    extends ConsumerState<RegisterPharmacyScreen>
    with TickerProviderStateMixin {
  // ── Step state ──
  int _step = 0; // 0,1,2

  // ── Form keys ──
  final _step1Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();

  // ── Field controllers (step 1) ──
  final _tenantName = TextEditingController();
  final _pharmacyEmail = TextEditingController();
  final _pharmacyPhone = TextEditingController();
  final _website = TextEditingController();
  final _city = TextEditingController();
  String _country = 'KE';

  // ── Field controllers (step 2) ──
  final _address = TextEditingController();
  double? _lat;
  double? _lng;
  bool _gettingLocation = false;
  String? _locationError;

  // ── Field controllers (step 3) ──
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  // ── Referral ──
  final _referralCode = TextEditingController();
  bool _validatingCode = false;
  bool _referralValid = false;
  String? _referralMsg;
  String? _referralError;
  Timer? _referralTimer;

  // ── Submit ──
  bool _loading = false;
  String? _errorMsg;
  bool _success = false;

  // ── Background animation ──
  late final AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tenantName.dispose();
    _pharmacyEmail.dispose();
    _pharmacyPhone.dispose();
    _website.dispose();
    _city.dispose();
    _address.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _referralCode.dispose();
    _referralTimer?.cancel();
    _floatCtrl.dispose();
    super.dispose();
  }

  // ── Step navigation ──────────────────────────────────────────────────────
  void _goNext() async {
    if (_step == 0) {
      if (!_step1Key.currentState!.validate()) return;
      setState(() => _step = 1);
    } else if (_step == 1) {
      setState(() => _step = 2);
    }
  }

  void _goBack() {
    if (_step > 0) setState(() => _step = _step - 1);
  }

  // ── Live location ────────────────────────────────────────────────────────
  Future<void> _detectLocation() async {
    setState(() {
      _gettingLocation = true;
      _locationError = null;
    });
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        setState(() {
          _locationError =
              'Location permission denied. Please enable it in settings.';
          _gettingLocation = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        if (_address.text.trim().isEmpty) {
          _address.text =
              '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
        }
        _gettingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationError = 'Failed to get location: $e';
        _gettingLocation = false;
      });
    }
  }

  void _clearLocation() {
    setState(() {
      _address.clear();
      _lat = null;
      _lng = null;
      _locationError = null;
    });
  }

  // ── Referral validation ──────────────────────────────────────────────────
  void _onReferralChanged(String v) {
    _referralTimer?.cancel();
    setState(() {
      _referralValid = false;
      _referralMsg = null;
      _referralError = null;
    });
    final code = v.trim();
    if (code.length < 4) return;
    _referralTimer = Timer(const Duration(milliseconds: 500), () {
      _validateReferral(code);
    });
  }

  Future<void> _validateReferral(String code) async {
    setState(() => _validatingCode = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/usage-billing/referral/validate/${code.toUpperCase()}/',
      );
      final data = res.data as Map<String, dynamic>;
      if (data['valid'] == true) {
        setState(() {
          _referralValid = true;
          _referralMsg = 'Referred by: ${data['referrer_name'] ?? 'partner'}';
        });
      } else {
        setState(() => _referralError = 'Invalid referral code');
      }
    } catch (_) {
      setState(() => _referralError = 'Could not validate code');
    } finally {
      if (mounted) setState(() => _validatingCode = false);
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────────
  Future<void> _onSubmit() async {
    setState(() => _errorMsg = null);
    if (!_step3Key.currentState!.validate()) return;

    setState(() => _loading = true);
    final navigator = GoRouter.of(context);
    try {
      final slug = _tenantName.text
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      final shortSlug = slug.length > 50 ? slug.substring(0, 50) : slug;
      final domain = '$shortSlug.adheremed.com';

      final dio = ref.read(dioProvider);
      await dio.post(
        '/tenants/register/',
        data: {
          'name': _tenantName.text.trim(),
          'type': 'pharmacy',
          'slug': shortSlug,
          'domain': domain,
          'email': _pharmacyEmail.text.trim(),
          'phone': _pharmacyPhone.text.trim(),
          'address': _address.text.trim(),
          'city': _city.text.trim(),
          'country': _country,
          'admin_email': _email.text.trim(),
          'admin_password': _password.text,
          'admin_first_name': _firstName.text.trim(),
          'admin_last_name': _lastName.text.trim(),
          'referral_code':
              _referralCode.text.trim().toUpperCase(),
        },
        options: Options(receiveTimeout: const Duration(seconds: 180)),
      );
      if (!mounted) return;
      setState(() {
        _success = true;
        _loading = false;
      });
      Timer(const Duration(milliseconds: 1500), () {
        navigator.go('/login');
      });
    } catch (e) {
      String msg = 'Registration failed.';
      if (e is DioException) {
        final d = e.response?.data;
        if (d is Map) {
          if (d['detail'] != null) {
            msg = d['detail'].toString();
          } else {
            msg = d.entries
                .map((e) =>
                    '${e.key}: ${e.value is List ? (e.value as List).join(' ') : e.value}')
                .join(' · ');
          }
        } else if (d is String && d.isNotEmpty) {
          msg = d;
        }
      }
      if (!mounted) return;
      setState(() {
        _errorMsg = msg;
        _loading = false;
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bgDeep,
      body: Stack(children: [
        const _BackgroundBase(),
        const _BackgroundGrid(),
        AnimatedBuilder(
          animation: _floatCtrl,
          builder: (_, __) => CustomPaint(
            size: size,
            painter: _BlobsPainter(t: _floatCtrl.value),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BackBar(onBack: () => context.go('/welcome')),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _Card(
                      child: _success ? _SuccessView() : _stepperContent(),
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: .03, end: 0),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _stepperContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        _CardHeader(
          icon: Icons.local_pharmacy_rounded,
          title: 'Register your Pharmacy',
          subtitle:
              'Create your pharmacy tenant on AdhereMed — POS, inventory, dispensing & analytics',
        ),
        const SizedBox(height: 20),

        if (_errorMsg != null) ...[
          _InlineAlert(message: _errorMsg!, isError: true),
          const SizedBox(height: 14),
        ],

        _StepHeader(
          step: _step,
          labels: const ['Pharmacy Info', 'Location', 'Admin Account'],
        ),
        const SizedBox(height: 18),

        if (_step == 0) _buildStep1(),
        if (_step == 1) _buildStep2(),
        if (_step == 2) _buildStep3(),
      ],
    );
  }

  // ── Step 1: Pharmacy Info ────────────────────────────────────────────────
  Widget _buildStep1() {
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepOverline('Pharmacy details'),
          const SizedBox(height: 12),
          _DarkField(
            controller: _tenantName,
            label: 'Pharmacy name *',
            icon: Icons.store_rounded,
            validator: _required,
          ),
          const SizedBox(height: 10),
          _DarkField(
            controller: _pharmacyEmail,
            label: 'Pharmacy email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          _DarkField(
            controller: _pharmacyPhone,
            label: 'Pharmacy phone',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          _DarkField(
            controller: _website,
            label: 'Website',
            icon: Icons.language_rounded,
            hint: 'https://',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 10),
          _DarkField(
            controller: _city,
            label: 'City / Town',
            icon: Icons.location_city_rounded,
          ),
          const SizedBox(height: 10),
          _CountryDropdown(
            value: _country,
            onChanged: (v) => setState(() => _country = v ?? 'KE'),
          ),
          const SizedBox(height: 20),
          Row(children: [
            const Spacer(),
            _PrimaryGradientButton(
              label: 'Next: Location',
              trailing: Icons.arrow_forward_rounded,
              onTap: _goNext,
            ),
          ]),
        ],
      ),
    );
  }

  // ── Step 2: Location ─────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StepOverline('Pharmacy address & location'),
        const SizedBox(height: 12),
        _DarkField(
          controller: _address,
          label: 'Address',
          icon: Icons.location_on_outlined,
          hint: 'Type the pharmacy address',
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _OutlineButton(
              icon: Icons.my_location_rounded,
              label: 'Detect current location',
              loading: _gettingLocation,
              onTap: _detectLocation,
            ),
          ),
        ]),
        if (_locationError != null) ...[
          const SizedBox(height: 10),
          _InlineAlert(message: _locationError!, isError: false),
        ],
        if (_lat != null && _lng != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _blueDark.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _blueSoft.withValues(alpha: 0.3),
              ),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: _blueSoft),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _address.text.isEmpty
                          ? 'Coordinates captured'
                          : _address.text,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _clearLocation,
                icon: Icon(Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.7), size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ),
        ],
        const SizedBox(height: 22),
        Row(children: [
          _GhostBackButton(onTap: _goBack),
          const Spacer(),
          _PrimaryGradientButton(
            label: 'Next: Admin Account',
            trailing: Icons.arrow_forward_rounded,
            onTap: _goNext,
          ),
        ]),
      ],
    );
  }

  // ── Step 3: Admin Account ────────────────────────────────────────────────
  Widget _buildStep3() {
    return Form(
      key: _step3Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepOverline('Admin account'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _DarkField(
                controller: _firstName,
                label: 'First name *',
                icon: Icons.person_outline,
                validator: _required,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DarkField(
                controller: _lastName,
                label: 'Last name *',
                icon: Icons.person_outline,
                validator: _required,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          _DarkField(
            controller: _email,
            label: 'Admin email *',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (!RegExp(r'.+@.+\..+').hasMatch(v.trim())) {
                return 'Invalid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          _DarkField(
            controller: _phone,
            label: 'Admin phone',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          _DarkField(
            controller: _password,
            label: 'Password *',
            icon: Icons.lock_outline_rounded,
            obscure: _obscure,
            suffix: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.white.withValues(alpha: 0.55),
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              if (v.length < 8) return 'Min 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 14),
          const _StepOverline('Referral (optional)'),
          const SizedBox(height: 10),
          _DarkField(
            controller: _referralCode,
            label: 'Referral Code',
            icon: Icons.card_giftcard_rounded,
            hint: 'Enter a referral code if you have one',
            onChanged: _onReferralChanged,
            suffix: _validatingCode
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _blueSoft,
                      ),
                    ),
                  )
                : (_referralValid
                    ? Icon(Icons.check_circle_rounded,
                        color: Colors.green.shade300, size: 20)
                    : null),
            helper: _referralMsg,
            errorText: _referralError,
          ),
          const SizedBox(height: 22),
          Row(children: [
            _GhostBackButton(onTap: _goBack),
            const Spacer(),
            _PrimaryGradientButton(
              label: 'Register Pharmacy',
              leading: Icons.local_pharmacy_rounded,
              onTap: _onSubmit,
              loading: _loading,
            ),
          ]),
          const SizedBox(height: 18),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Already registered? ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 13,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/login'),
                  child: const Text(
                    'Sign in',
                    style: TextStyle(
                      color: _blueSoft,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;
}

// ═══════════════════════════════════════════════════════════════════════════
//  SUCCESS VIEW
// ═══════════════════════════════════════════════════════════════════════════
class _SuccessView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.45),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded,
                color: Colors.white, size: 44),
          ),
          const SizedBox(height: 18),
          const Text(
            'Pharmacy created successfully!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Redirecting to sign in…',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: _blueSoft,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════
class _BackBar extends StatelessWidget {
  final VoidCallback onBack;
  const _BackBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Back to home'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _CardHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [_blueLight, _blueDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _bluePrimary.withValues(alpha: 0.5),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
      const SizedBox(height: 14),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 13,
          height: 1.4,
        ),
      ),
    ]);
  }
}

class _StepHeader extends StatelessWidget {
  final int step;
  final List<String> labels;
  const _StepHeader({required this.step, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++) ...[
          _StepDot(
            number: i + 1,
            label: labels[i],
            active: step == i,
            complete: step > i,
          ),
          if (i < labels.length - 1)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                height: 1.5,
                decoration: BoxDecoration(
                  color: step > i
                      ? _blueLight
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
        ],
      ]),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int number;
  final String label;
  final bool active;
  final bool complete;
  const _StepDot({
    required this.number,
    required this.label,
    required this.active,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) {
    final color = complete || active ? _blueLight : Colors.white24;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: (complete || active)
                ? const LinearGradient(
                    colors: [_blueLight, _blueDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: !(complete || active)
                ? Colors.white.withValues(alpha: 0.06)
                : null,
            border: Border.all(color: color.withValues(alpha: 0.4)),
            boxShadow: (active || complete)
                ? [
                    BoxShadow(
                      color: _bluePrimary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: complete
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
              : Text(
                  '$number',
                  style: TextStyle(
                    color: active ? Colors.white : Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: active
                ? Colors.white
                : Colors.white.withValues(alpha: 0.55),
            fontSize: 10.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StepOverline extends StatelessWidget {
  final String text;
  const _StepOverline(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: _blueSoft,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  DARK FIELD
// ═══════════════════════════════════════════════════════════════════════════
class _DarkField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final Widget? suffix;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final String? helper;
  final String? errorText;

  const _DarkField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.suffix,
    this.obscure = false,
    this.keyboardType,
    this.onChanged,
    this.validator,
    this.helper,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: _blueSoft,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 13,
        ),
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 13,
        ),
        helperText: helper,
        helperStyle: TextStyle(
          color: Colors.green.shade300,
          fontSize: 11.5,
        ),
        errorText: errorText,
        prefixIcon: Icon(icon,
            color: Colors.white.withValues(alpha: 0.45), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: _blueSoft.withValues(alpha: 0.7), width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1.4),
        ),
        errorStyle: TextStyle(color: Colors.red.shade200, fontSize: 11.5),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  COUNTRY DROPDOWN
// ═══════════════════════════════════════════════════════════════════════════
class _CountryDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  const _CountryDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      dropdownColor: _bgEdge,
      iconEnabledColor: Colors.white70,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Country *',
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 13,
        ),
        prefixIcon: Icon(Icons.public_rounded,
            color: Colors.white.withValues(alpha: 0.45), size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: _blueSoft.withValues(alpha: 0.7), width: 1.4),
        ),
      ),
      items: _countries
          .map((c) => DropdownMenuItem(
                value: c.code,
                child: Text(c.name),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  BUTTONS / ALERTS
// ═══════════════════════════════════════════════════════════════════════════
class _PrimaryGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool loading;
  final IconData? leading;
  final IconData? trailing;
  const _PrimaryGradientButton({
    required this.label,
    required this.onTap,
    this.loading = false,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: loading ? null : onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_blueLight, _blueDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _bluePrimary.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Colors.white),
                )
              else if (leading != null) ...[
                Icon(leading, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              if (!loading) ...[
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Icon(trailing, color: Colors.white, size: 18),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;
  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: loading ? null : onTap,
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _blueIce,
              ),
            )
          : Icon(icon, size: 18, color: _blueIce),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _blueIce,
        side: BorderSide(color: _blueSoft.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GhostBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GhostBackButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.arrow_back_rounded, size: 16),
      label: const Text('Back'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

class _InlineAlert extends StatelessWidget {
  final String message;
  final bool isError;
  const _InlineAlert({required this.message, this.isError = true});

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red : Colors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(
          isError
              ? Icons.error_outline_rounded
              : Icons.warning_amber_rounded,
          color: color.shade200,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: color.shade100, fontSize: 12.5),
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
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(0.6, -1.2),
            end: Alignment(-0.4, 1.2),
            colors: [_bgDeep, _bgMid, _bgEdge],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SizedBox.expand(),
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
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    const step = 56.0;
    final maxY = size.height * 0.6;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, maxY), paint);
    }
    for (double y = 0; y < maxY; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
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
    final wave = math.sin(t * math.pi * 2);
    void blob(Offset c, double r, Color color) {
      final paint = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70);
      canvas.drawCircle(c, r, paint);
    }

    blob(
      Offset(size.width + 40 - 80 * wave.abs(), -60 + 10 * wave),
      190,
      _bluePrimary.withValues(alpha: 0.38),
    );
    blob(
      Offset(-80 + 60 * wave.abs(), size.height - 40 - 20 * wave),
      170,
      _blueDark.withValues(alpha: 0.28),
    );
  }

  @override
  bool shouldRepaint(covariant _BlobsPainter old) => old.t != t;
}
