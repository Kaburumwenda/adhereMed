import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api.dart';

// ═════════════════════════════════════════════════════════════════
//  Shared helpers + premium widgets for the Homecare module.
//  Mirrors the design language of the web homecare workspace
//  (teal #0D9488 primary, soft slate surfaces, rounded 16-24).
// ═════════════════════════════════════════════════════════════════

const hcTeal = Color(0xFF0D9488);
const hcBlue = Color(0xFF0284C7);
const hcIndigo = Color(0xFF4F46E5);
const hcPurple = Color(0xFF8B5CF6);
const hcAmber = Color(0xFFF59E0B);
const hcRose = Color(0xFFF43F5E);
const hcGreen = Color(0xFF059669);
const hcRed = Color(0xFFDC2626);
const hcSlate = Color(0xFF64748B);

// ── Pagination-aware fetch (mirrors web fetchAll) ──
Future<List<dynamic>> hcFetchAll(dynamic ref, String url,
    {Map<String, dynamic>? params}) async {
  final dio = ref.read(dioProvider);
  final out = <dynamic>[];
  String? next = url;
  var qp = params;
  var guard = 0;
  while (next != null && guard < 15) {
    final res = await dio.get(next, queryParameters: qp);
    qp = null; // only first request carries params; `next` embeds them
    final data = res.data;
    if (data is List) {
      out.addAll(data);
      break;
    }
    out.addAll((data['results'] as List?) ?? const []);
    next = data['next'] as String?;
    if (next != null && next.contains('/api/')) {
      next = next.substring(next.indexOf('/api/') + 4);
    }
    guard++;
  }
  return out;
}

// ── Formatting ──
String hcDate(dynamic v) {
  if (v == null || v == '') return '—';
  final d = DateTime.tryParse(v.toString())?.toLocal();
  if (d == null) return '—';
  return DateFormat('dd MMM yyyy').format(d);
}

String hcTime(dynamic v) {
  if (v == null || v == '') return '';
  final d = DateTime.tryParse(v.toString())?.toLocal();
  if (d == null) return '';
  return DateFormat('HH:mm').format(d);
}

String hcDateTime(dynamic v) {
  if (v == null || v == '') return '—';
  final d = DateTime.tryParse(v.toString())?.toLocal();
  if (d == null) return '—';
  return DateFormat('dd MMM, HH:mm').format(d);
}

String hcTimeRange(dynamic a, dynamic b) => '${hcTime(a)} – ${hcTime(b)}';

String hcInitials(String? name) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+'));
  final letters =
      parts.where((p) => p.isNotEmpty).take(2).map((p) => p[0]).join();
  return letters.isEmpty ? '?' : letters.toUpperCase();
}

String hcMoney(dynamic v, {String currency = 'KSh'}) {
  final n = double.tryParse(v?.toString() ?? '') ?? 0;
  return '$currency ${NumberFormat('#,##0.##').format(n)}';
}

// ── Status colors (visit + dose + escalation), same palette as web ──
Color hcVisitStatusColor(String? s) => switch (s) {
      'scheduled' => hcBlue,
      'checked_in' => hcTeal,
      'completed' => hcGreen,
      'missed' => hcRed,
      'cancelled' => hcSlate,
      _ => hcSlate,
    };

Color hcDoseStatusColor(String? s) => switch (s) {
      'pending' => hcAmber,
      'taken' => hcGreen,
      'missed' => hcRed,
      'skipped' => hcSlate,
      'not_given' => hcRed,
      'overdue' => hcRed,
      _ => hcSlate,
    };

Color hcRiskColor(String? level) => switch (level) {
      'critical' => hcRed,
      'high' => const Color(0xFFEA580C),
      'medium' => hcAmber,
      'low' => hcGreen,
      _ => hcSlate,
    };

Color hcSeverityColor(String? s) => switch (s) {
      'critical' => hcRed,
      'high' => const Color(0xFFEA580C),
      'medium' => hcAmber,
      _ => hcBlue,
    };

// ── Category helpers (caregiver roles) ──
Color hcCategoryColor(String? c) => switch (c) {
      'nurse' => hcIndigo,
      'hca' => const Color(0xFFEC4899),
      _ => hcTeal,
    };

IconData hcCategoryIcon(String? c) => switch (c) {
      'nurse' => Icons.medical_services_rounded,
      'hca' => Icons.volunteer_activism_rounded,
      _ => Icons.favorite_rounded,
    };

String hcCategoryLabel(String? c) => switch (c) {
      'nurse' => 'Nurse',
      'hca' => 'HCA',
      _ => 'Caregiver',
    };

// ── Shift type helpers ──
Color hcShiftTypeColor(String? t) => switch (t) {
      'visit' => hcTeal,
      'live_in' => hcPurple,
      'on_call' => hcBlue,
      _ => hcSlate,
    };

IconData hcShiftTypeIcon(String? t) => switch (t) {
      'visit' => Icons.directions_walk_rounded,
      'live_in' => Icons.home_rounded,
      'on_call' => Icons.phone_in_talk_rounded,
      _ => Icons.calendar_month_rounded,
    };

String hcShiftTypeLabel(String? t) => switch (t) {
      'visit' => 'Visit',
      'live_in' => 'Live-in',
      'on_call' => 'On call',
      'multi_visit' => 'Multiple visits',
      _ => t ?? '—',
    };

// ── Shift bucket (day/night/livein/oncall) for row tinting ──
String hcShiftBucket(Map s) {
  final st = s['shift_type']?.toString() ?? '';
  if (st == 'live_in') return 'livein';
  if (st == 'on_call') return 'oncall';
  final hour = DateTime.tryParse(s['start_at']?.toString() ?? '')?.toLocal().hour ?? 8;
  if (hour >= 18 || hour < 6) return 'night';
  return 'day';
}

Color hcBucketColor(String bucket) => switch (bucket) {
      'livein' => hcPurple,
      'oncall' => hcBlue,
      'night' => hcIndigo,
      _ => hcAmber,
    };

// ── Availability / coverage bar colors (mirrors web) ──
Color hcAvailColor(int pct) {
  if (pct >= 90) return const Color(0xFFEF4444);
  if (pct >= 70) return hcAmber;
  if (pct >= 40) return hcIndigo;
  return const Color(0xFF10B981);
}

Color hcCoverageColor(int pct) {
  if (pct >= 75) return const Color(0xFF10B981);
  if (pct >= 40) return hcIndigo;
  if (pct >= 15) return hcAmber;
  return const Color(0xFFEF4444);
}

// ── Format minutes as "Xh Ym" ──
String hcFormatHours(num? min) {
  final m = (min ?? 0).clamp(0, 999999).toInt();
  final h = m ~/ 60, r = m % 60;
  if (h == 0 && r == 0) return '0h';
  if (h == 0) return '${r}m';
  if (r == 0) return '${h}h';
  return '${h}h ${r}m';
}

// ── Format relative time ("in 2 h", "in 3 days") ──
String hcFormatRelative(dynamic v) {
  final target = DateTime.tryParse(v?.toString() ?? '');
  if (target == null) return '';
  final now = DateTime.now();
  final diffMin = target.difference(now).inMinutes;
  if (diffMin < 0) return hcTime(v);
  if (diffMin < 60) return 'in $diffMin min';
  final hrs = (diffMin / 60).round();
  if (hrs < 24) return 'in ${hrs}h (${hcTime(v)})';
  final days = (hrs / 24).round();
  return 'in $days day${days == 1 ? '' : 's'}';
}

// ── Split ISO into local date/time strings ──
({String date, String time}) hcSplitDateTime(dynamic iso) {
  final d = DateTime.tryParse(iso?.toString() ?? '')?.toLocal();
  if (d == null) return (date: '', time: '');
  return (
    date: '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
    time: '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
  );
}

// ── ISO date string for offset from today ──
String hcDateOffset(int n) {
  final d = DateTime.now().add(Duration(days: n));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ── Format short date ("Mon, Jan 5") ──
String hcFormatDateShort(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';
  final d = DateTime.tryParse('${dateStr}T00:00');
  if (d == null) return '';
  return DateFormat('EEE, d MMM').format(d);
}

String hcLabel(String? s) {
  if (s == null || s.isEmpty) return '—';
  return s
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

// ── Directions to a patient (auto-picks caregiver GPS, mirrors web) ──
Future<void> hcOpenDirections(
  BuildContext context, {
  double? destLat,
  double? destLng,
  String? address,
}) async {
  String dest;
  if (destLat != null && destLng != null) {
    dest = '$destLat,$destLng';
  } else if ((address ?? '').trim().isNotEmpty) {
    dest = address!.trim();
  } else {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No address on file for this patient.')));
    return;
  }

  String? origin;
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Location access is blocked — allow location to route from where you are. Showing the patient location.')));
      }
    } else {
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10)));
      origin = '${pos.latitude},${pos.longitude}';
    }
  } catch (_) {/* fall through to destination-only */}

  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': dest,
    if (origin != null) 'origin': origin,
    'travelmode': 'driving',
  });
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// ── Capture current GPS (for check-in/out). Returns null + snackbar on failure. ──
Future<Map<String, dynamic>?> hcCaptureGps(BuildContext context) async {
  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Location permission is required to verify the visit.')));
      }
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
    return {
      'lat': pos.latitude,
      'lng': pos.longitude,
      'accuracy': pos.accuracy,
      'captured_at': DateTime.now().toUtc().toIso8601String(),
    };
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get your location.')));
    }
    return null;
  }
}

// ═════════════════════════════════════════════════════════════════
//  Widgets
// ═════════════════════════════════════════════════════════════════

/// Gradient hero header used across homecare screens.
class HcHero extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String eyebrow;
  final IconData icon;
  final List<Widget> chips;
  final List<Color>? gradient;
  final Widget? trailing;
  const HcHero({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow = 'HOMECARE',
    this.icon = Icons.home_work_rounded,
    this.chips = const [],
    this.gradient,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final g = gradient ?? const [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: g.first.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 12)),
        ],
      ),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(eyebrow,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4)),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13)),
            ],
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
            ],
          ]),
        ),
        if (trailing != null) trailing!,
        if (trailing == null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
      ]),
    );
  }
}

/// Translucent white chip used inside [HcHero].
class HcHeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const HcHeroChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Compact KPI stat tile.
class HcKpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? hint;
  final VoidCallback? onTap;
  const HcKpi(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      required this.color,
      this.hint,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          color,
                          Color.lerp(color, Colors.black, 0.15)!
                        ]),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: color.withValues(alpha: 0.45),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ]),
                    child: Icon(icon, color: Colors.white, size: 17),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: cs.onSurfaceVariant)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color)),
                if (hint != null)
                  Text(hint!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
              ]),
        ),
      ),
    );
  }
}

/// Panel card with an icon + title header, mirrors web HomecarePanel.
class HcPanel extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Widget child;
  final Widget? action;
  const HcPanel(
      {super.key,
      required this.title,
      this.subtitle,
      required this.icon,
      this.color = hcTeal,
      required this.child,
      this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14.5)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: TextStyle(
                              fontSize: 11.5, color: cs.onSurfaceVariant)),
                  ]),
            ),
            if (action != null) action!,
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }
}

/// Tonal status chip.
class HcStatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const HcStatusChip(
      {super.key, required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(7)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4)
        ],
        Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Circle avatar with initials on a tinted background.
class HcAvatar extends StatelessWidget {
  final String? name;
  final double size;
  final Color color;
  const HcAvatar({super.key, this.name, this.size = 40, this.color = hcTeal});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(hcInitials(name),
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.34)),
    );
  }
}

/// Simple label/value row used in detail sheets.
class HcInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  const HcInfoRow(
      {super.key, required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
        ],
        SizedBox(
            width: 118,
            child: Text(label,
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant))),
        Expanded(
            child: Text(value.isEmpty ? '—' : value,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

/// Full-screen scrollable pull-to-refresh wrapper with async value handling.
class HcAsyncBody<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Future<void> Function() onRefresh;
  final Widget Function(T data) builder;
  const HcAsyncBody(
      {super.key,
      required this.value,
      required this.onRefresh,
      required this.builder});

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded,
                size: 44, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            const Text('Could not load data', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry')),
          ]),
        ),
      ),
      data: (d) => RefreshIndicator(onRefresh: onRefresh, child: builder(d)),
    );
  }
}

/// PIN entry field with a "reveal my PIN" helper (mirrors web pattern).
class HcPinField extends StatefulWidget {
  final TextEditingController controller;
  final String? myPin;
  const HcPinField({super.key, required this.controller, this.myPin});

  @override
  State<HcPinField> createState() => _HcPinFieldState();
}

class _HcPinFieldState extends State<HcPinField> {
  bool _reveal = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: widget.controller,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(
          labelText: 'Your 6-digit staff PIN',
          prefixIcon: Icon(Icons.key_rounded),
          counterText: '',
        ),
      ),
      if (widget.myPin != null && widget.myPin!.isNotEmpty)
        GestureDetector(
          onTap: () => setState(() => _reveal = !_reveal),
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _reveal
                  ? 'My PIN: ${widget.myPin}  (tap to hide)'
                  : "Don't know your PIN? Tap to reveal",
              style: TextStyle(fontSize: 12, color: cs.primary),
            ),
          ),
        ),
    ]);
  }
}
