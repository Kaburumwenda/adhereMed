import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import 'hc_common.dart';

// ═════════════════ DATA SHARING ═════════════════
final _sharingOverviewProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/homecare/patients/sharing-overview/');
  final data = res.data;
  return data is List ? data : ((data?['results'] as List?) ?? []);
});

const _shareCategories = [
  {'key': 'share_profile',        'label': 'Profile',           'icon': Icons.card_membership_rounded,  'color': hcIndigo},
  {'key': 'share_care_team',      'label': 'Care team',         'icon': Icons.group_rounded,            'color': hcBlue},
  {'key': 'share_vitals',         'label': 'Vitals',            'icon': Icons.favorite_rounded,         'color': hcRed},
  {'key': 'share_medications',    'label': 'Medications',      'icon': Icons.medication_rounded,        'color': hcTeal},
  {'key': 'share_treatment_plan', 'label': 'Treatment plan',   'icon': Icons.assignment_rounded,       'color': hcPurple},
  {'key': 'share_notes',          'label': 'Visit notes',      'icon': Icons.edit_note_rounded,         'color': hcAmber},
  {'key': 'share_adherence',      'label': 'Adherence',        'icon': Icons.show_chart_rounded,        'color': hcGreen},
  {'key': 'share_escalations',    'label': 'Escalations',      'icon': Icons.warning_rounded,          'color': hcRed},
  {'key': 'share_consents',       'label': 'Consents',         'icon': Icons.description_rounded,      'color': hcSlate},
  {'key': 'share_documents',      'label': 'Documents',        'icon': Icons.attach_file_rounded,       'color': hcIndigo},
];

class HomecareDataSharingScreen extends ConsumerStatefulWidget {
  const HomecareDataSharingScreen({super.key});

  @override
  ConsumerState<HomecareDataSharingScreen> createState() =>
      _HomecareDataSharingScreenState();
}

class _HomecareDataSharingScreenState
    extends ConsumerState<HomecareDataSharingScreen> {
  String _search = '';
  String _filter = ''; // '' | 'full' | 'restricted'
  final Set<dynamic> _saving = {};
  final Set<int> _expanded = {};

  bool _isFullyShared(Map r) {
    if (r['is_shared'] != true) return false;
    return _shareCategories.every((c) => r[c['key'] as String] == true);
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(_sharingOverviewProvider);
    final cs = Theme.of(context).colorScheme;
    return HcAsyncBody(
      value: overview,
      onRefresh: () async => ref.refresh(_sharingOverviewProvider.future),
      builder: (list) {
        final allRows = list.cast<Map>().toList();
        final fullyShared = allRows.where(_isFullyShared).length;
        final restricted = allRows.length - fullyShared;

        var rows = allRows;
        if (_filter == 'full') {
          rows = allRows.where(_isFullyShared).toList();
        } else if (_filter == 'restricted') {
          rows = allRows.where((r) => !_isFullyShared(r)).toList();
        }
        if (_search.isNotEmpty) {
          final q = _search.toLowerCase();
          rows = rows.where((r) =>
              (r['patient_name'] ?? '').toString().toLowerCase().contains(q) ||
              (r['medical_record_number'] ?? '').toString().toLowerCase().contains(q)).toList();
        }

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _buildHero(cs, allRows.length, fullyShared, restricted),
            _buildInfoBanner(cs),
            _buildStatTiles(allRows.length, fullyShared, restricted),
            _buildSearch(cs),
            if (rows.isEmpty)
              _buildEmptyState(cs)
            else
              ...rows.map((r) {
                final patientId = r['patient'] ?? r['patient_id'] ?? r['id'];
                return _ShareCard(
                  row: r,
                  saving: _saving.contains(patientId),
                  expanded: _expanded.contains(patientId is int ? patientId : int.tryParse(patientId.toString())),
                  onToggle: (key, value) => _save(r, key, value),
                  onExpand: () => setState(() {
                    final id = patientId is int ? patientId : int.tryParse(patientId.toString());
                    if (id != null && _expanded.contains(id)) {
                      _expanded.remove(id);
                    } else if (id != null) {
                      _expanded.add(id);
                    }
                  }),
                );
              }),
          ],
        );
      },
    );
  }

  // ── Premium hero ──
  Widget _buildHero(ColorScheme cs, int total, int full, int restricted) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: hcTeal.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.share_rounded, color: Colors.white, size: 28),
          ),
          const Spacer(),
          if (_saving.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        Text('PRIVACY',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6)),
        const SizedBox(height: 4),
        const Text('Data Sharing',
            style: TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(
          'Control what each enrolled patient can see in their own AdhereMed portal.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _heroChip(Icons.group_rounded, '$total patients'),
          _heroChip(Icons.visibility_rounded, '$full fully shared'),
          _heroChip(Icons.visibility_off_rounded, '$restricted restricted'),
        ]),
      ]),
    );
  }

  Widget _heroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Info banner ──
  Widget _buildInfoBanner(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [hcBlue.withValues(alpha: 0.06), hcIndigo.withValues(alpha: 0.06)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hcBlue.withValues(alpha: 0.18)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: hcBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.shield_rounded, color: hcBlue, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Patients sign in to their own account — they never log in to your homecare workspace. '
            'They only see the categories switched on below. By default everything is shared.',
            style: TextStyle(fontSize: 12, height: 1.45, color: cs.onSurfaceVariant),
          ),
        ),
      ]),
    );
  }

  // ── Stat tiles row ──
  Widget _buildStatTiles(int total, int full, int restricted) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: [
      Expanded(
        child: _StatTile(
          icon: Icons.people_rounded, label: 'Patients', value: '$total',
          color: hcTeal,
          active: _filter == '',
          onTap: () => setState(() => _filter = ''),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatTile(
          icon: Icons.visibility_rounded, label: 'Fully shared', value: '$full',
          color: hcGreen,
          active: _filter == 'full',
          onTap: () => setState(() => _filter = _filter == 'full' ? '' : 'full'),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _StatTile(
          icon: Icons.visibility_off_rounded, label: 'Restricted', value: '$restricted',
          color: hcAmber,
          active: _filter == 'restricted',
          onTap: () => setState(() => _filter = _filter == 'restricted' ? '' : 'restricted'),
        ),
      ),
      ]),
    );
  }

  // ── Search ──
  Widget _buildSearch(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search patient or record number…',
          prefixIcon: Icon(Icons.search_rounded, color: cs.onSurfaceVariant, size: 22),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => setState(() => _search = ''),
                )
              : null,
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          isDense: true,
          hintStyle: TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  // ── Empty state ──
  Widget _buildEmptyState(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [hcSlate.withValues(alpha: 0.12), hcSlate.withValues(alpha: 0.04)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_off_rounded, size: 38, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 16),
            const Text('No enrolled patients',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 6),
            Text('Enrol a patient to manage their data sharing.',
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Future<void> _save(Map r, String key, bool value) async {
    final patientId = r['patient'] ?? r['patient_id'] ?? r['id'];
    setState(() => _saving.add(patientId));
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/homecare/patients/$patientId/sharing/', data: {key: value});
      r[key] = value;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Text('Sharing updated'),
          ]),
          backgroundColor: hcGreen,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(milliseconds: 1800),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Text('Failed to save'),
          ]),
          backgroundColor: hcRed,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(milliseconds: 2000),
        ));
      }
      ref.invalidate(_sharingOverviewProvider);
    } finally {
      if (mounted) setState(() => _saving.remove(patientId));
    }
  }
}

// ── Stat tile (KPI card) ──
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _StatTile({
    required this.icon, required this.label, required this.value,
    required this.color, required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.08) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: active ? Border.all(color: color.withValues(alpha: 0.35), width: 1.5) : null,
        boxShadow: active
            ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant, letterSpacing: 0.3)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Patient share card ──
class _ShareCard extends StatefulWidget {
  final Map row;
  final bool saving;
  final bool expanded;
  final void Function(String key, bool value) onToggle;
  final VoidCallback onExpand;
  const _ShareCard({
    required this.row, required this.saving,
    required this.expanded, required this.onToggle, required this.onExpand,
  });

  @override
  State<_ShareCard> createState() => _ShareCardState();
}

class _ShareCardState extends State<_ShareCard> with SingleTickerProviderStateMixin {
  late bool _isShared;
  late Map<String, bool> _cats;
  late AnimationController _animCtrl;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _isShared = widget.row['is_shared'] == true;
    _cats = {
      for (final c in _shareCategories)
        c['key'] as String: widget.row[c['key'] as String] == true,
    };
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    if (widget.expanded) _animCtrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_ShareCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row != widget.row) {
      _isShared = widget.row['is_shared'] == true;
      _cats = {
        for (final c in _shareCategories)
          c['key'] as String: widget.row[c['key'] as String] == true,
      };
    }
    if (oldWidget.expanded != widget.expanded) {
      if (widget.expanded) {
        _animCtrl.forward();
      } else {
        _animCtrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle(String key, bool value) {
    setState(() {
      if (key == 'is_shared') {
        _isShared = value;
      } else {
        _cats[key] = value;
      }
    });
    widget.onToggle(key, value);
  }

  int get _sharedCount => _cats.values.where((v) => v).length;
  int get _totalCount => _cats.length;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accentColor = _isShared ? hcTeal : hcSlate;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(children: [
          // ── Accent bar ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: 3,
            color: accentColor,
          ),
          // ── Header ──
          InkWell(
            onTap: widget.onExpand,
            borderRadius: BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(children: [
                // Avatar with ring
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: HcAvatar(
                    name: widget.row['patient_name']?.toString(),
                    size: 42,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.row['patient_name']?.toString() ?? '—',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(children: [
                      if ((widget.row['medical_record_number'] ?? '').toString().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (widget.row['medical_record_number'] ?? '').toString(),
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
                          ),
                        ),
                      const SizedBox(width: 8),
                      // Sharing summary
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(_isShared ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              size: 11, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            _isShared ? '$_sharedCount/$_totalCount' : 'OFF',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: accentColor),
                          ),
                        ]),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(width: 6),
                // Expand chevron or saving indicator
                if (widget.saving)
                  const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                else
                  AnimatedRotation(
                    turns: widget.expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(Icons.chevron_right_rounded, size: 26, color: cs.onSurfaceVariant),
                  ),
              ]),
            ),
          ),
          // ── Progress bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _isShared ? _sharedCount / _totalCount : 0,
                minHeight: 4,
                backgroundColor: cs.surfaceContainerHighest,
                color: accentColor,
              ),
            ),
          ),
          // ── Master toggle row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Row(children: [
              Icon(_isShared ? Icons.lock_open_rounded : Icons.lock_rounded,
                  size: 16, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isShared ? 'Sharing enabled — tap to expand categories' : 'Sharing disabled — all categories hidden',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
                ),
              ),
              SizedBox(
                height: 28,
                child: Switch(
                  value: _isShared,
                  onChanged: (v) => _toggle('is_shared', v),
                  activeThumbColor: hcTeal,
                  activeTrackColor: hcTeal.withValues(alpha: 0.35),
                  inactiveThumbColor: cs.onSurfaceVariant,
                  inactiveTrackColor: cs.surfaceContainerHighest,
                ),
              ),
            ]),
          ),
          // ── Expandable category section ──
          SizeTransition(
            sizeFactor: _expandAnim,
            axisAlignment: -1.0,
            child: AnimatedOpacity(
              opacity: _isShared ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  children: _shareCategories.map((c) {
                    final key = c['key'] as String;
                    final icon = c['icon'] as IconData;
                    final label = c['label'] as String;
                    final catColor = c['color'] as Color;
                    final catValue = _cats[key] ?? true;
                    final active = _isShared && catValue;
                    return _CategoryToggleRow(
                      icon: icon,
                      label: label,
                      color: catColor,
                      value: catValue,
                      enabled: _isShared,
                      active: active,
                      onChanged: (v) => _toggle(key, v),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Category toggle row with icon tile ──
class _CategoryToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool value;
  final bool enabled;
  final bool active;
  final ValueChanged<bool> onChanged;
  const _CategoryToggleRow({
    required this.icon, required this.label, required this.color,
    required this.value, required this.enabled, required this.active,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        // Icon tile
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.14) : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: color.withValues(alpha: 0.3), width: 1) : null,
          ),
          child: Icon(icon, size: 17,
              color: active ? color : cs.onSurfaceVariant.withValues(alpha: 0.4)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.6))),
        ),
        SizedBox(
          height: 26,
          child: Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: color,
            activeTrackColor: color.withValues(alpha: 0.35),
            inactiveThumbColor: cs.onSurfaceVariant,
            inactiveTrackColor: cs.surfaceContainerHighest,
          ),
        ),
      ]),
    );
  }
}

// ═════════════════ COMPANY PROFILE ═════════════════
final _companyProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/homecare/company-profile/');
  final data = res.data;
  if (data is List) return data.isNotEmpty ? data.first as Map : <String, dynamic>{};
  final results = data?['results'] as List?;
  if (results != null) {
    return results.isNotEmpty ? results.first as Map : <String, dynamic>{};
  }
  return (data as Map?) ?? <String, dynamic>{};
});

class HomecareCompanyProfileScreen extends ConsumerWidget {
  const HomecareCompanyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(_companyProvider);
    return HcAsyncBody(
      value: profile,
      onRefresh: () async => ref.refresh(_companyProvider.future),
      builder: (p) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: 'ORGANISATION',
              title: (p['name'] ?? 'Company profile').toString(),
              subtitle: (p['tagline'] ?? p['description'] ?? '').toString(),
              icon: Icons.business_rounded,
            ),
            HcPanel(
              title: 'Details',
              icon: Icons.business_rounded,
              color: hcTeal,
              child: Column(children: [
                HcInfoRow(
                    label: 'Name',
                    value: (p['name'] ?? '').toString(),
                    icon: Icons.badge_rounded),
                HcInfoRow(
                    label: 'Phone',
                    value: (p['phone'] ?? '').toString(),
                    icon: Icons.call_rounded),
                HcInfoRow(
                    label: 'Email',
                    value: (p['email'] ?? '').toString(),
                    icon: Icons.mail_rounded),
                HcInfoRow(
                    label: 'Website',
                    value: (p['website'] ?? '').toString(),
                    icon: Icons.language_rounded),
                HcInfoRow(
                    label: 'Address',
                    value: (p['address'] ?? '').toString(),
                    icon: Icons.home_rounded),
                HcInfoRow(
                    label: 'License',
                    value: (p['license_number'] ?? '').toString(),
                    icon: Icons.verified_user_rounded),
              ]),
            ),
          ],
        );
      },
    );
  }
}

// ═════════════════ ESCALATION RULES ═════════════════
final _rulesProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/escalation-rules/',
      params: {'page_size': 100});
});

class HomecareEscalationRulesScreen extends ConsumerWidget {
  const HomecareEscalationRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(_rulesProvider);
    return HcAsyncBody(
      value: rules,
      onRefresh: () async => ref.refresh(_rulesProvider.future),
      builder: (list) {
        final rows = list.cast<Map>();
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: 'CLINICAL SAFETY',
              title: 'Escalation rules',
              subtitle: 'Automatic triggers that open escalations',
              icon: Icons.rule_folder_rounded,
              gradient: const [
                Color(0xFF7F1D1D),
                Color(0xFFB91C1C),
                Color(0xFFDC2626)
              ],
              chips: [
                HcHeroChip(
                    icon: Icons.rule_rounded, label: '${rows.length} rules'),
              ],
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('No escalation rules.')),
              )
            else
              ...rows.map((r) {
                final active = r['is_active'] != false;
                return Card(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: ListTile(
                    leading: Icon(Icons.bolt_rounded,
                        color: active ? hcAmber : hcSlate),
                    title: Text(r['name']?.toString() ?? '—',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13.5)),
                    subtitle: Text(
                        (r['description'] ?? r['condition'] ?? '')
                            .toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5)),
                    trailing: HcStatusChip(
                        label: active ? 'ACTIVE' : 'DISABLED',
                        color: active ? hcGreen : hcSlate),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}
