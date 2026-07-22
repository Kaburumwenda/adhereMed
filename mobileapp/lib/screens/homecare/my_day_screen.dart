import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api.dart';
import '../../providers/auth_provider.dart';
import 'hc_common.dart';
import 'visit_check_sheet.dart';

final _myDayProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/homecare/caregivers/me/my-day/');
  return res.data as Map<String, dynamic>;
});

/// Caregiver "My Day": today's visits (check-in / check-out with
/// acknowledgement + GPS + PIN) and one-tap dose documentation.
class HomecareMyDayScreen extends ConsumerWidget {
  const HomecareMyDayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(_myDayProvider);

    return HcAsyncBody(
      value: day,
      onRefresh: () async => ref.refresh(_myDayProvider.future),
      builder: (d) {
        final caregiver = (d['caregiver'] as Map?) ?? {};
        final visits = (d['visits'] as List?) ?? [];
        final doses = (d['doses'] as List?) ?? [];
        final pending = doses.where((x) => x['status'] == 'pending').length;
        final taken = doses.where((x) => x['status'] == 'taken').length;
        final done = visits.where((x) => x['status'] == 'completed').length;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: 'MY DAY',
              title: DateFormat('EEEE, d MMMM').format(DateTime.now()),
              subtitle:
                  '${visits.length} visits scheduled · $pending doses pending',
              icon: Icons.today_rounded,
              chips: [
                HcHeroChip(
                    icon: Icons.check_circle_rounded,
                    label: '$done visits done'),
                HcHeroChip(
                    icon: Icons.medication_rounded, label: '$taken doses taken'),
                HcHeroChip(
                    icon: Icons.star_rounded,
                    label: '${caregiver['rating'] ?? 0} rating'),
              ],
            ).animate().fadeIn(duration: 300.ms),
            HcPanel(
              title: "Today's visits",
              subtitle: 'Check in on arrival, check out when done',
              icon: Icons.schedule_rounded,
              color: hcTeal,
              child: visits.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: Text('No visits today. Enjoy your day off!')),
                    )
                  : Column(
                      children: visits
                          .map<Widget>((v) => _VisitCard(
                              visit: v as Map,
                              onChanged: () =>
                                  ref.invalidate(_myDayProvider)))
                          .toList(),
                    ),
            ),
            HcPanel(
              title: "Today's doses",
              subtitle: 'PIN-verified medication documentation',
              icon: Icons.medication_liquid_rounded,
              color: hcBlue,
              child: doses.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: Text('No doses scheduled today.')),
                    )
                  : Column(
                      children: doses
                          .map<Widget>((x) => _DoseCard(
                              dose: x as Map,
                              onChanged: () =>
                                  ref.invalidate(_myDayProvider)))
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════
//  Visit card + check-in/out sheet
// ═════════════════════════════════════════════════════════════════
class _VisitCard extends ConsumerWidget {
  final Map visit;
  final VoidCallback onChanged;
  const _VisitCard({required this.visit, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = visit['status']?.toString() ?? '';
    final color = hcVisitStatusColor(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          HcAvatar(name: visit['patient_name']?.toString(), color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(visit['patient_name']?.toString() ?? '—',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(hcTimeRange(visit['start_at'], visit['end_at']),
                      style: const TextStyle(fontSize: 12)),
                  if ((visit['patient_address'] ?? '')
                      .toString()
                      .isNotEmpty)
                    Text(visit['patient_address'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                ]),
          ),
          HcStatusChip(label: hcLabel(status), color: color),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          OutlinedButton.icon(
            onPressed: () => hcOpenDirections(
              context,
              destLat: double.tryParse('${visit['patient_address_lat']}'),
              destLng: double.tryParse('${visit['patient_address_lng']}'),
              address: visit['patient_address']?.toString(),
            ),
            icon: const Icon(Icons.directions_rounded, size: 17),
            label: const Text('Directions'),
            style: OutlinedButton.styleFrom(
                foregroundColor: hcIndigo,
                visualDensity: VisualDensity.compact),
          ),
          const Spacer(),
          if (status == 'scheduled')
            FilledButton.icon(
              onPressed: () => _openCheckSheet(context, ref, 'in'),
              icon: const Icon(Icons.login_rounded, size: 17),
              label: const Text('Check in'),
              style: FilledButton.styleFrom(
                  backgroundColor: hcTeal,
                  visualDensity: VisualDensity.compact),
            ),
          if (status == 'checked_in')
            FilledButton.icon(
              onPressed: () => _openCheckSheet(context, ref, 'out'),
              icon: const Icon(Icons.logout_rounded, size: 17),
              label: const Text('Check out'),
              style: FilledButton.styleFrom(
                  backgroundColor: hcGreen,
                  visualDensity: VisualDensity.compact),
            ),
        ]),
      ]),
    );
  }

  void _openCheckSheet(BuildContext context, WidgetRef ref, String action) {
    showVisitCheckSheet(context, visit: visit, action: action, onDone: onChanged);
  }
}

// ═════════════════════════════════════════════════════════════════
//  Dose card + PIN action sheet
// ═════════════════════════════════════════════════════════════════
class _DoseCard extends ConsumerWidget {
  final Map dose;
  final VoidCallback onChanged;
  const _DoseCard({required this.dose, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = dose['status']?.toString() ?? '';
    final color = hcDoseStatusColor(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
          child: Icon(Icons.medication_rounded, color: color, size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(dose['medication_name']?.toString() ?? '—',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13.5)),
            Text(
                '${dose['dose'] ?? ''} · ${dose['patient_name'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
            Text(hcTime(dose['scheduled_at']),
                style: const TextStyle(
                    fontSize: 11.5,
                    color: hcTeal,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        if (status == 'pending')
          FilledButton.tonal(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24))),
              builder: (_) => _DoseActionSheet(dose: dose, onDone: onChanged),
            ),
            style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact),
            child: const Text('Record'),
          )
        else
          HcStatusChip(label: hcLabel(status), color: color),
      ]),
    );
  }
}

class _DoseActionSheet extends ConsumerStatefulWidget {
  final Map dose;
  final VoidCallback onDone;
  const _DoseActionSheet({required this.dose, required this.onDone});

  @override
  ConsumerState<_DoseActionSheet> createState() => _DoseActionSheetState();
}

class _DoseActionSheetState extends ConsumerState<_DoseActionSheet> {
  String _action = 'taken'; // taken | skipped | missed
  final _pin = TextEditingController();
  final _reason = TextEditingController();
  bool _saving = false;

  Future<void> _submit() async {
    final pin = _pin.text.trim();
    if (pin.isEmpty) return;
    if (_action == 'skipped' && _reason.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A reason is required to skip a dose.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final verb = switch (_action) {
        'taken' => 'mark_taken',
        'skipped' => 'mark_skipped',
        _ => 'mark_missed',
      };
      await dio.post('/homecare/doses/${widget.dose['id']}/$verb/', data: {
        'pin': pin,
        if (_reason.text.trim().isNotEmpty) 'reason': _reason.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Dose updated.')));
        widget.onDone();
      }
    } catch (e) {
      String msg = 'Could not update dose.';
      try {
        final data = (e as dynamic).response?.data;
        if (data is Map && data['detail'] != null) {
          msg = data['detail'].toString();
        }
      } catch (_) {}
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final cs = Theme.of(context).colorScheme;

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
          Text('Record dose',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text(
              '${widget.dose['medication_name']} · ${widget.dose['dose']} · ${widget.dose['patient_name']}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'taken',
                  label: Text('Taken'),
                  icon: Icon(Icons.check_rounded)),
              ButtonSegment(
                  value: 'skipped',
                  label: Text('Skip'),
                  icon: Icon(Icons.skip_next_rounded)),
              ButtonSegment(
                  value: 'missed',
                  label: Text('Missed'),
                  icon: Icon(Icons.close_rounded)),
            ],
            selected: {_action},
            onSelectionChanged: (s) => setState(() => _action = s.first),
          ),
          const SizedBox(height: 12),
          if (_action != 'taken')
            TextField(
              controller: _reason,
              decoration: InputDecoration(
                labelText:
                    _action == 'skipped' ? 'Reason (required)' : 'Reason',
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
          if (_action != 'taken') const SizedBox(height: 12),
          HcPinField(controller: _pin, myPin: auth.user?.pin),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
