import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../providers/auth_provider.dart';
import 'hc_common.dart';

/// Opens the GPS + PIN verified check-in / check-out bottom sheet.
void showVisitCheckSheet(BuildContext context,
    {required Map visit, required String action, required VoidCallback onDone}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => VisitCheckSheet(visit: visit, action: action, onDone: onDone),
  );
}

/// Check-in / check-out sheet: acknowledgement + live GPS + staff PIN,
/// exactly matching the backend contract (`acknowledged`, `gps`, `pin`).
class VisitCheckSheet extends ConsumerStatefulWidget {
  final Map visit;
  final String action; // 'in' | 'out'
  final VoidCallback onDone;
  const VisitCheckSheet(
      {super.key,
      required this.visit,
      required this.action,
      required this.onDone});

  @override
  ConsumerState<VisitCheckSheet> createState() => _VisitCheckSheetState();
}

class _VisitCheckSheetState extends ConsumerState<VisitCheckSheet> {
  bool _acknowledged = false;
  Map<String, dynamic>? _gps;
  bool _locating = false;
  bool _saving = false;
  final _pin = TextEditingController();

  bool get isIn => widget.action == 'in';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  Future<void> _capture() async {
    setState(() => _locating = true);
    final gps = await hcCaptureGps(context);
    if (mounted) {
      setState(() {
        _gps = gps;
        _locating = false;
      });
    }
  }

  Future<void> _submit() async {
    final pin = _pin.text.trim();
    if (!_acknowledged || _gps == null || pin.length < 4) return;
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final verb = isIn ? 'check_in' : 'check_out';
      await dio.post('/homecare/schedules/${widget.visit['id']}/$verb/',
          data: {'acknowledged': true, 'pin': pin, 'gps': _gps});
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isIn
                ? 'Checked in — shift is in progress.'
                : 'Checked out — shift completed.')));
        widget.onDone();
      }
    } catch (e) {
      final msg = _errorText(e);
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  String _errorText(dynamic e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data is Map) {
        for (final k in ['detail', 'pin', 'gps', 'acknowledged']) {
          final v = data[k];
          if (v != null) return v is List ? v.first.toString() : v.toString();
        }
      }
    } catch (_) {}
    return 'Failed to record check-${widget.action}.';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final cs = Theme.of(context).colorScheme;
    final canSubmit =
        _acknowledged && _gps != null && _pin.text.trim().length >= 4;

    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: (isIn ? hcTeal : hcGreen).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(isIn ? Icons.login_rounded : Icons.logout_rounded,
                  color: isIn ? hcTeal : hcGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isIn ? 'Check in to shift' : 'Check out of shift',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(
                        '${widget.visit['patient_name']} · ${hcTimeRange(widget.visit['start_at'], widget.visit['end_at'])}',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  ]),
            ),
          ]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: hcBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12)),
            child: Text(
              'By continuing you confirm you are physically with the patient. '
              'Your live location and identity are recorded for compliance.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
          CheckboxListTile(
            value: _acknowledged,
            onChanged: (v) => setState(() => _acknowledged = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              isIn
                  ? 'I acknowledge this visit and accept GPS + PIN verification.'
                  : 'I confirm the visit is complete and accept GPS + PIN verification.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(
                  _gps != null
                      ? Icons.check_circle_rounded
                      : Icons.location_searching_rounded,
                  color: _gps != null ? hcGreen : hcAmber,
                  size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _locating
                      ? 'Getting your location…'
                      : _gps != null
                          ? 'Location captured (±${(_gps!['accuracy'] as num?)?.round() ?? '—'} m)'
                          : 'Location required — tap capture',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
              TextButton.icon(
                onPressed: _locating ? null : _capture,
                icon: _locating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location_rounded, size: 16),
                label: Text(_gps != null ? 'Refresh' : 'Capture'),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          HcPinField(controller: _pin, myPin: auth.user?.pin),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: canSubmit && !_saving ? _submit : null,
                style: FilledButton.styleFrom(
                    backgroundColor: isIn ? hcTeal : hcGreen),
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(isIn ? Icons.login_rounded : Icons.logout_rounded,
                        size: 18),
                label:
                    Text(isIn ? 'Confirm check-in' : 'Confirm check-out'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
