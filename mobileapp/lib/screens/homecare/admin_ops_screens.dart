import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' as share_plus;
import 'package:timeago/timeago.dart' as timeago;
import '../../core/api.dart';
import 'hc_common.dart';

// ═════════════════ INSURANCE (policies + claims) ═════════════════
final _policiesProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/insurance-policies/',
      params: {'page_size': 200});
});
final _claimsProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/insurance-claims/',
      params: {'page_size': 200});
});

class HomecareInsuranceScreen extends ConsumerWidget {
  const HomecareInsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Insurance',
              style: TextStyle(fontWeight: FontWeight.w800)),
          bottom: const TabBar(tabs: [
            Tab(text: 'Policies', icon: Icon(Icons.policy_rounded, size: 18)),
            Tab(text: 'Claims', icon: Icon(Icons.gavel_rounded, size: 18)),
          ]),
        ),
        body: TabBarView(children: [
          _PoliciesTab(),
          _ClaimsTab(),
        ]),
      ),
    );
  }
}

class _PoliciesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policies = ref.watch(_policiesProvider);
    return HcAsyncBody(
      value: policies,
      onRefresh: () async => ref.refresh(_policiesProvider.future),
      builder: (list) {
        final rows = list.cast<Map>();
        if (rows.isEmpty) {
          return const Center(child: Text('No insurance policies.'));
        }
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final p = rows[i];
            final active = p['is_active'] == true;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.policy_rounded, color: hcBlue),
                title: Text(
                    '${p['provider_name'] ?? '—'} · ${p['policy_number'] ?? ''}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13)),
                subtitle: Text(
                    '${p['patient_name'] ?? ''}${p['valid_to'] != null ? ' · valid to ${hcDate(p['valid_to'])}' : ''}',
                    style: const TextStyle(fontSize: 11.5)),
                trailing: HcStatusChip(
                    label: active ? 'ACTIVE' : 'INACTIVE',
                    color: active ? hcGreen : hcSlate),
              ),
            );
          },
        );
      },
    );
  }
}

class _ClaimsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(_claimsProvider);
    return HcAsyncBody(
      value: claims,
      onRefresh: () async => ref.refresh(_claimsProvider.future),
      builder: (list) {
        final rows = list.cast<Map>();
        if (rows.isEmpty) return const Center(child: Text('No claims.'));
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (_, i) {
            final c = rows[i];
            final status = (c['status'] ?? '').toString();
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.gavel_rounded, color: hcPurple),
                title: Text(
                    '${c['claim_number'] ?? 'Claim #${c['id']}'} · ${hcMoney(c['amount_requested'])}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13)),
                subtitle: Text(
                    '${c['patient_name'] ?? ''} · ${hcLabel(c['claim_type']?.toString())} · ${hcDate(c['created_at'])}',
                    style: const TextStyle(fontSize: 11.5)),
                trailing: HcStatusChip(
                    label: hcLabel(status),
                    color: status == 'paid' || status == 'approved'
                        ? hcGreen
                        : status == 'denied'
                            ? hcRed
                            : hcAmber),
              ),
            );
          },
        );
      },
    );
  }
}

// ═════════════════ EQUIPMENT / DEVICES ═════════════════
final _devicesProvider = FutureProvider.autoDispose((ref) async {
  final results = await Future.wait([
    hcFetchAll(ref, '/homecare/devices/', params: {'page_size': 500}),
    hcFetchAll(ref, '/homecare/device-assignments/',
        params: {'page_size': 200}),
    hcFetchAll(ref, '/homecare/patients/',
        params: {'is_active': 'true', 'page_size': 500}),
  ]);
  Map<String, dynamic> summary = {};
  try {
    final dio = ref.read(dioProvider);
    final s = await dio.get('/homecare/devices/summary/');
    summary = (s.data as Map?)?.cast<String, dynamic>() ?? {};
  } catch (_) {}
  return {
    'devices': results[0],
    'assignments': results[1],
    'patients': results[2],
    'summary': summary,
  };
});

// ── Device type metadata ──
const _typeMeta = <String, (IconData, Color)>{
  'oximeter': (Icons.favorite_rounded, Color(0xFFEF4444)),
  'bp_monitor': (Icons.speed_rounded, Color(0xFF0EA5E9)),
  'glucometer': (Icons.water_drop_rounded, Color(0xFFF59E0B)),
  'thermometer': (Icons.thermostat_rounded, Color(0xFFF97316)),
  'oxygen': (Icons.air_rounded, Color(0xFF06B6D4)),
  'nebulizer': (Icons.air_rounded, Color(0xFF14B8A6)),
  'bed': (Icons.bed_rounded, Color(0xFF8B5CF6)),
  'wheelchair': (Icons.accessible_rounded, Color(0xFF6366F1)),
  'walker': (Icons.directions_walk_rounded, Color(0xFF0D9488)),
  'suction': (Icons.precision_manufacturing_rounded, Color(0xFF64748B)),
  'ventilator': (Icons.air_rounded, Color(0xFFDC2626)),
  'infusion_pump': (Icons.medical_services_rounded, Color(0xFF3B82F6)),
  'ecg': (Icons.monitor_heart_rounded, Color(0xFFE11D48)),
  'other': (Icons.medical_information_rounded, Color(0xFF7C3AED)),
};

const _typeOptions = <(String, String)>[
  ('oximeter', 'Pulse Oximeter'),
  ('bp_monitor', 'BP Monitor'),
  ('glucometer', 'Glucometer'),
  ('thermometer', 'Thermometer'),
  ('oxygen', 'Oxygen Concentrator'),
  ('nebulizer', 'Nebulizer'),
  ('bed', 'Hospital Bed'),
  ('wheelchair', 'Wheelchair'),
  ('walker', 'Walker / Crutches'),
  ('suction', 'Suction Machine'),
  ('ventilator', 'Ventilator'),
  ('infusion_pump', 'Infusion Pump'),
  ('ecg', 'ECG Monitor'),
  ('other', 'Other'),
];

const _statusOptions = <(String, String)>[
  ('available', 'Available'),
  ('assigned', 'Assigned'),
  ('maintenance', 'In Maintenance'),
  ('repair', 'Needs Repair'),
  ('retired', 'Retired'),
  ('lost', 'Lost / Missing'),
];

const _periodOptions = <(String, String)>[
  ('hourly', 'Per Hour'),
  ('daily', 'Per Day'),
  ('weekly', 'Per Week'),
  ('monthly', 'Per Month'),
];

const _maintenanceKinds = <(String, String)>[
  ('routine', 'Routine Service'),
  ('calibration', 'Calibration'),
  ('repair', 'Repair'),
  ('inspection', 'Safety Inspection'),
];

const _conditionOptions = ['Good', 'Fair', 'Damaged', 'Needs repair', 'Lost'];

const _notAvailableStatuses = ['maintenance', 'repair', 'retired', 'lost'];

IconData _typeIcon(String? t) =>
    (_typeMeta[t] ?? _typeMeta['other']!).$1;
Color _typeColor(String? t) =>
    (_typeMeta[t] ?? _typeMeta['other']!).$2;

num _toNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? 0;
}

Color _stockColor(Map dev) {
  final avail = _toNum(dev['quantity_available']);
  final threshold = _toNum(dev['low_stock_threshold']) == 0 ? 1 : _toNum(dev['low_stock_threshold']);
  if (avail <= 0) return hcRed;
  if (avail <= threshold) return hcAmber;
  return hcGreen;
}

Color _statusColor(String? s) => switch (s) {
      'available' => hcGreen,
      'assigned' => hcBlue,
      'maintenance' => hcAmber,
      'repair' => hcRose,
      'retired' => hcSlate,
      'lost' => hcRed,
      _ => hcSlate,
    };

bool _isAvailable(Map i) {
  final avail = _toNum(i['quantity_available']);
  return avail > 0 && !_notAvailableStatuses.contains(i['status']);
}

bool _isOnHire(Map i) => _toNum(i['quantity_on_hire']) > 0;

bool _isAlmostOut(Map i) {
  final avail = _toNum(i['quantity_available']);
  final threshold = _toNum(i['low_stock_threshold']);
  return avail > 0 && avail <= (threshold == 0 ? 1 : threshold);
}

double? _primaryRate(Map item) {
  final period = item['default_hire_period']?.toString() ?? 'daily';
  final raw = item['${period}_rate'] ??
      item['daily_rate'] ??
      item['hourly_rate'] ??
      item['weekly_rate'] ??
      item['monthly_rate'];
  if (raw == null) return null;
  return double.tryParse(raw.toString());
}

String _periodShort(String? p) =>
    {'hourly': 'hr', 'daily': 'day', 'weekly': 'wk', 'monthly': 'mo'}[p] ??
    p ??
    'day';

String _typeLabel(String? t) {
  for (final e in _typeOptions) {
    if (e.$1 == t) return e.$2;
  }
  return hcLabel(t);
}

String _nowLocal() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class HomecareEquipmentScreen extends ConsumerStatefulWidget {
  const HomecareEquipmentScreen({super.key});

  @override
  ConsumerState<HomecareEquipmentScreen> createState() =>
      _HomecareEquipmentScreenState();
}

class _HomecareEquipmentScreenState
    extends ConsumerState<HomecareEquipmentScreen> {
  String _search = '';
  String? _filterType;
  String? _filterStatus;
  String _tab = 'all';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(_devicesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Equipment',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add device',
            onPressed: () => _openDeviceDialog(context, null),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'assign-device',
        backgroundColor: hcIndigo,
        foregroundColor: Colors.white,
        onPressed: () => _openAssignFromFab(context),
        icon: const Icon(Icons.assignment_turned_in_rounded),
        label: const Text('Assign'),
      ),
      body: HcAsyncBody(
        value: data,
        onRefresh: () async => ref.refresh(_devicesProvider.future),
        builder: (d) {
          final devices = (d['devices'] as List).cast<Map>();
          final assignments = (d['assignments'] as List).cast<Map>();
          final summary = (d['summary'] as Map?) ?? {};

          final onHire = assignments.where((a) => a['returned_at'] == null).length;
          final maintenanceDue = summary['maintenance_due_soon'] ?? 0;
          final realizedRevenue = summary['realized_revenue'] ?? 0;
          final depositsHeld = summary['deposits_held'] ?? 0;
          final availableCount =
              summary['available'] ?? devices.where((i) => i['status'] == 'available').length;
          final assignedCount =
              summary['assigned'] ?? devices.where((i) => i['status'] == 'assigned').length;
          final maintenanceCount =
              summary['maintenance'] ?? devices.where((i) => i['status'] == 'maintenance').length;

          final filtered = _applyFilters(devices);

          final counts = {
            'all': devices.length,
            'available': devices.where(_isAvailable).length,
            'on_hire': devices.where(_isOnHire).length,
            'almost_out': devices.where(_isAlmostOut).length,
          };

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 90),
            children: [
              HcHero(
                eyebrow: 'ASSETS & RENTALS',
                title: 'Medical Equipment',
                subtitle:
                    'Track devices, set hire rates, schedule maintenance and manage patient assignments.',
                icon: Icons.medical_information_rounded,
                gradient: const [
                  Color(0xFF312E81),
                  Color(0xFF4338CA),
                  Color(0xFF4F46E5)
                ],
                chips: [
                  HcHeroChip(
                      icon: Icons.inventory_2_rounded,
                      label: '${devices.length} items'),
                  HcHeroChip(
                      icon: Icons.assignment_turned_in_rounded,
                      label: '$onHire on hire'),
                  HcHeroChip(
                      icon: Icons.build_rounded,
                      label: '$maintenanceDue service due'),
                  HcHeroChip(
                      icon: Icons.paid_rounded,
                      label: '${hcMoney(realizedRevenue)} earned'),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.3,
                  children: [
                    HcKpi(
                        label: 'Available',
                        value: '$availableCount',
                        icon: Icons.check_circle_rounded,
                        color: hcGreen),
                    HcKpi(
                        label: 'On hire',
                        value: '$assignedCount',
                        icon: Icons.local_shipping_rounded,
                        color: hcBlue),
                    HcKpi(
                        label: 'In maintenance',
                        value: '$maintenanceCount',
                        icon: Icons.build_rounded,
                        color: hcAmber),
                    HcKpi(
                        label: 'Deposits held',
                        value: hcMoney(depositsHeld),
                        icon: Icons.savings_rounded,
                        color: hcPurple),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildTabs(counts),
              _buildSearchAndFilters(),
              HcPanel(
                title: 'Equipment inventory',
                subtitle: 'All trackable assets & hire pricing',
                icon: Icons.inventory_2_rounded,
                color: hcPurple,
                child: filtered.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: Text('No devices found.')),
                      )
                    : Column(
                        children: filtered
                            .map<Widget>((dev) => _deviceTile(dev))
                            .toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Map> _applyFilters(List<Map> devices) {
    var rows = devices;
    if (_tab == 'available') {
      rows = rows.where(_isAvailable).toList();
    } else if (_tab == 'on_hire') {
      rows = rows.where(_isOnHire).toList();
    } else if (_tab == 'almost_out') {
      rows = rows.where(_isAlmostOut).toList();
    }
    if (_filterType != null) {
      rows = rows.where((d) => d['device_type'] == _filterType).toList();
    }
    if (_filterStatus != null) {
      rows = rows.where((d) => d['status'] == _filterStatus).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      rows = rows.where((d) {
        final blob =
            '${d['name'] ?? ''} ${d['serial_number'] ?? ''} ${d['asset_tag'] ?? ''} ${d['manufacturer'] ?? ''}'
                .toLowerCase();
        return blob.contains(q);
      }).toList();
    }
    return rows;
  }

  // ── Tabs ──
  Widget _buildTabs(Map<String, dynamic> counts) {
    final tabs = [
      ('all', 'All', counts['all'] ?? 0, hcSlate),
      ('available', 'Available', counts['available'] ?? 0, hcGreen),
      ('on_hire', 'On hire', counts['on_hire'] ?? 0, hcBlue),
      ('almost_out', 'Almost out', counts['almost_out'] ?? 0, hcAmber),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: tabs
              .map((t) {
                final (key, label, count, color) = t;
                final active = _tab == key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(label),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: active
                              ? Colors.white.withValues(alpha: 0.25)
                              : color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? Colors.white
                                  : color),
                        ),
                      ),
                    ]),
                    selected: active,
                    onSelected: (v) => setState(() => _tab = key),
                    selectedColor: color,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    showCheckmark: false,
                  ),
                );
              })
              .toList(),
        ),
      ),
    );
  }

  // ── Search + filters ──
  Widget _buildSearchAndFilters() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(children: [
        // Search
        TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search name, serial, asset tag…',
            prefixIcon: Icon(Icons.search_rounded,
                color: cs.onSurfaceVariant, size: 22),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => setState(() => _search = ''))
                : null,
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            isDense: true,
            hintStyle: TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _filterType,
              decoration: InputDecoration(
                labelText: 'Type',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All types')),
                ..._typeOptions.map((e) =>
                    DropdownMenuItem(value: e.$1, child: Text(e.$2))),
              ],
              onChanged: (v) => setState(() => _filterType = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _filterStatus,
              decoration: InputDecoration(
                labelText: 'Status',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('All statuses')),
                ..._statusOptions.map((e) =>
                    DropdownMenuItem(value: e.$1, child: Text(e.$2))),
              ],
              onChanged: (v) => setState(() => _filterStatus = v),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── Device tile ──
  Widget _deviceTile(Map dev) {
    final cs = Theme.of(context).colorScheme;
    final typeColor = _typeColor(dev['device_type']?.toString());
    final stockCol = _stockColor(dev);
    final avail = _toNum(dev['quantity_available']);
    final total = _toNum(dev['quantity']);
    final onHire = _toNum(dev['quantity_on_hire']);
    final isRentable = dev['is_rentable'] == true;
    final rate = _primaryRate(dev);
    final status = dev['status']?.toString() ?? 'available';
    final nextMaint = dev['next_maintenance_due'];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openHistory(context, dev),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_typeIcon(dev['device_type']?.toString()),
                  color: typeColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          (dev['name'] ?? '—').toString(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      _actionMenu(dev),
                    ]),
                    const SizedBox(height: 2),
                    Text(
                      '${dev['manufacturer'] ?? '—'}${dev['model_number'] != null ? ' · ${dev['model_number']}' : ''}',
                      style: TextStyle(
                          fontSize: 11.5, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      HcStatusChip(
                          label: _typeLabel(dev['device_type']?.toString()),
                          color: typeColor),
                      HcStatusChip(
                          label: '$avail / $total',
                          color: stockCol),
                      if (onHire > 0)
                        HcStatusChip(
                            label: '$onHire on hire', color: hcBlue),
                      HcStatusChip(
                          label: hcLabel(status), color: _statusColor(status)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      if (isRentable && rate != null) ...[
                        Icon(Icons.paid_rounded,
                            size: 14, color: hcTeal),
                        const SizedBox(width: 4),
                        Text(
                          '${hcMoney(rate)} / ${_periodShort(dev['default_hire_period']?.toString())}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: hcTeal),
                        ),
                      ] else
                        Text('Not for hire',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                      const Spacer(),
                      if (nextMaint != null)
                        _nextServiceChip(nextMaint),
                    ]),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _actionMenu(Map dev) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
            value: 'history',
            child: ListTile(
                leading: Icon(Icons.history_rounded),
                title: Text('History & details'),
                contentPadding: EdgeInsets.zero,
                dense: true)),
        if (_isAvailable(dev))
          const PopupMenuItem(
              value: 'assign',
              child: ListTile(
                  leading: Icon(Icons.assignment_turned_in_rounded),
                  title: Text('Assign / hire out'),
                  contentPadding: EdgeInsets.zero,
                  dense: true)),
        if (_isOnHire(dev))
          const PopupMenuItem(
              value: 'return',
              child: ListTile(
                  leading: Icon(Icons.keyboard_return_rounded),
                  title: Text('Return device'),
                  contentPadding: EdgeInsets.zero,
                  dense: true)),
        const PopupMenuItem(
            value: 'maintenance',
            child: ListTile(
                leading: Icon(Icons.build_rounded),
                title: Text('Schedule maintenance'),
                contentPadding: EdgeInsets.zero,
                dense: true)),
        const PopupMenuItem(
            value: 'edit',
            child: ListTile(
                leading: Icon(Icons.edit_rounded),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
                dense: true)),
        const PopupMenuDivider(),
        const PopupMenuItem(
            value: 'delete',
            child: ListTile(
                leading: Icon(Icons.delete_rounded, color: hcRed),
                title: Text('Delete',
                    style: TextStyle(color: hcRed)),
                contentPadding: EdgeInsets.zero,
                dense: true)),
      ],
      onSelected: (action) {
        switch (action) {
          case 'history':
            _openHistory(context, dev);
            break;
          case 'assign':
            _openAssign(context, dev);
            break;
          case 'return':
            _openReturn(context, dev);
            break;
          case 'maintenance':
            _openMaintenance(context, dev);
            break;
          case 'edit':
            _openDeviceDialog(context, dev);
            break;
          case 'delete':
            _confirmDelete(context, dev);
            break;
        }
      },
    );
  }

  Widget _nextServiceChip(dynamic nextMaint) {
    final d = DateTime.tryParse(nextMaint.toString())?.toLocal();
    if (d == null) return const SizedBox.shrink();
    final days = d.difference(DateTime.now()).inDays;
    Color color;
    String label;
    if (days < 0) {
      color = hcRed;
      label = 'Overdue ${hcDate(nextMaint)}';
    } else if (days < 14) {
      color = hcAmber;
      label = 'Due ${hcDate(nextMaint)}';
    } else {
      color = Theme.of(context).colorScheme.onSurfaceVariant;
      label = hcDate(nextMaint);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.event_rounded, size: 13, color: color),
      const SizedBox(width: 3),
      Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    ]);
  }

  // ── Add / Edit device dialog ──
  void _openDeviceDialog(BuildContext context, Map? editing) {
    final isEdit = editing != null;
    final controllers = <String, TextEditingController>{};
    final fields = [
      'name', 'serial_number', 'asset_tag', 'manufacturer', 'model_number',
      'location', 'quantity', 'quantity_available', 'low_stock_threshold',
      'hourly_rate', 'daily_rate', 'weekly_rate', 'monthly_rate', 'deposit',
      'purchase_date', 'purchase_cost', 'warranty_expiry',
      'next_maintenance_due', 'notes'
    ];
    for (final f in fields) {
      final v = editing?[f];
      controllers[f] = TextEditingController(
          text: v == null ? '' : v.toString());
    }

    String deviceType = editing?['device_type']?.toString() ?? 'oximeter';
    String status = editing?['status']?.toString() ?? 'available';
    bool isRentable = editing?['is_rentable'] ?? true;
    String hirePeriod = editing?['default_hire_period']?.toString() ?? 'daily';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: bottomInset + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? 'Edit device' : 'Add device',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  const Text('IDENTITY',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: hcSlate)),
                  const SizedBox(height: 8),
                  TextField(
                      controller: controllers['name'],
                      decoration: const InputDecoration(
                          labelText: 'Name *',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: deviceType,
                    decoration: const InputDecoration(labelText: 'Type *'),
                    items: _typeOptions
                        .map((e) => DropdownMenuItem(
                            value: e.$1, child: Text(e.$2)))
                        .toList(),
                    onChanged: (v) =>
                        setSheetState(() => deviceType = v ?? 'oximeter'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: _statusOptions
                        .map((e) => DropdownMenuItem(
                            value: e.$1, child: Text(e.$2)))
                        .toList(),
                    onChanged: (v) =>
                        setSheetState(() => status = v ?? 'available'),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: controllers['serial_number'],
                            decoration: const InputDecoration(
                                labelText: 'Serial number'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: controllers['asset_tag'],
                            decoration: const InputDecoration(
                                labelText: 'Asset tag'))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: controllers['manufacturer'],
                            decoration: const InputDecoration(
                                labelText: 'Manufacturer'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: controllers['model_number'],
                            decoration: const InputDecoration(
                                labelText: 'Model #'))),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                      controller: controllers['location'],
                      decoration: const InputDecoration(
                          labelText: 'Storage location')),
                  const SizedBox(height: 18),
                  const Text('STOCK',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: hcSlate)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: controllers['quantity'],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Total quantity *'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: controllers['quantity_available'],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                                labelText: 'Available now',
                                hintText: isEdit ? null : 'Defaults to total'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: controllers['low_stock_threshold'],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Low-stock ≤'))),
                  ]),
                  const SizedBox(height: 18),
                  const Text('HIRE PRICING (KES)',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: hcSlate)),
                  SwitchListTile(
                    value: isRentable,
                    onChanged: (v) =>
                        setSheetState(() => isRentable = v),
                    title: const Text('Available for hire'),
                    dense: true,
                  ),
                  if (isRentable) ...[
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: controllers['hourly_rate'],
                              keyboardType: const TextInputType
                                  .numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'Hourly',
                                  prefixText: 'KSh '))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: TextField(
                              controller: controllers['daily_rate'],
                              keyboardType: const TextInputType
                                  .numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'Daily',
                                  prefixText: 'KSh '))),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              controller: controllers['weekly_rate'],
                              keyboardType: const TextInputType
                                  .numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'Weekly',
                                  prefixText: 'KSh '))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: TextField(
                              controller: controllers['monthly_rate'],
                              keyboardType: const TextInputType
                                  .numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                  labelText: 'Monthly',
                                  prefixText: 'KSh '))),
                    ]),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: hirePeriod,
                      decoration: const InputDecoration(
                          labelText: 'Default billing period'),
                      items: _periodOptions
                          .map((e) => DropdownMenuItem(
                              value: e.$1, child: Text(e.$2)))
                          .toList(),
                      onChanged: (v) =>
                          setSheetState(() => hirePeriod = v ?? 'daily'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                        controller: controllers['deposit'],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Refundable deposit',
                            prefixText: 'KSh ')),
                  ],
                  const SizedBox(height: 18),
                  const Text('ASSET & MAINTENANCE',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: hcSlate)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: controllers['purchase_date'],
                            decoration: const InputDecoration(
                                labelText: 'Purchased'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: controllers['purchase_cost'],
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Purchase cost',
                                prefixText: 'KSh '))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: controllers['warranty_expiry'],
                            decoration: const InputDecoration(
                                labelText: 'Warranty expiry'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: controllers['next_maintenance_due'],
                            decoration: const InputDecoration(
                                labelText: 'Next maintenance'))),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                      controller: controllers['notes'],
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes')),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: hcTeal),
                      onPressed: () async =>
                          _saveDevice(ctx, isEdit, editing, controllers, {
                        'device_type': deviceType,
                        'status': status,
                        'is_rentable': isRentable,
                        'default_hire_period': hirePeriod,
                      }),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveDevice(
      BuildContext sheetCtx,
      bool isEdit,
      Map? editing,
      Map<String, TextEditingController> controllers,
      Map<String, dynamic> extras) async {
    final name = controllers['name']!.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(sheetCtx).showSnackBar(
          const SnackBar(content: Text('Name is required.')));
      return;
    }
    final payload = <String, dynamic>{
      'name': name,
      'device_type': extras['device_type'],
      'status': extras['status'],
      'is_rentable': extras['is_rentable'],
      'default_hire_period': extras['default_hire_period'],
      'currency': 'KES',
    };
    void setNum(String key) {
      final txt = controllers[key]!.text.trim();
      if (txt.isNotEmpty) payload[key] = double.tryParse(txt) ?? int.tryParse(txt);
    }

    void setStr(String key) {
      final txt = controllers[key]!.text.trim();
      if (txt.isNotEmpty) payload[key] = txt;
    }

    setStr('serial_number');
    setStr('asset_tag');
    setStr('manufacturer');
    setStr('model_number');
    setStr('location');
    setNum('quantity');
    setNum('quantity_available');
    setNum('low_stock_threshold');
    if (extras['is_rentable'] == true) {
      setNum('hourly_rate');
      setNum('daily_rate');
      setNum('weekly_rate');
      setNum('monthly_rate');
      setNum('deposit');
    }
    setStr('purchase_date');
    setNum('purchase_cost');
    setStr('warranty_expiry');
    setStr('next_maintenance_due');
    setStr('notes');

    if (payload['quantity'] == null) payload['quantity'] = 1;
    if (payload['quantity_available'] == null) {
      payload['quantity_available'] = payload['quantity'];
    }

    try {
      final dio = ref.read(dioProvider);
      if (isEdit && editing != null) {
        await dio.patch('/homecare/devices/${editing['id']}/', data: payload);
      } else {
        await dio.post('/homecare/devices/', data: payload);
      }
      ref.invalidate(_devicesProvider);
      if (sheetCtx.mounted) Navigator.pop(sheetCtx);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isEdit ? 'Device updated.' : 'Device added.'),
            backgroundColor: hcGreen));
      }
    } catch (e) {
      if (sheetCtx.mounted) {
        ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(
            content: Text('Failed to save device.'),
            backgroundColor: hcRed));
      }
    }
  }

  // ── Assign / hire dialog ──
  void _openAssign(BuildContext context, Map dev) {
    final patients = (ref.read(_devicesProvider).valueOrNull?['patients']
            as List?) ??
        [];
    final defaultPeriod = dev['default_hire_period']?.toString() ?? 'daily';
    final rate = _primaryRate(dev);
    String hireToType = 'patient';
    int? patientId;
    final facilityCtrl = TextEditingController();
    String hirePeriod = defaultPeriod;
    final rateCtrl = TextEditingController(text: rate?.toString() ?? '');
    final depositCtrl =
        TextEditingController(text: (dev['deposit'] ?? '').toString());
    final startCtrl = TextEditingController(text: _nowLocal());
    final returnCtrl = TextEditingController();
    final hoursCtrl = TextEditingController(text: '1');
    final notesCtrl = TextEditingController();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          int hireUnits = 0;
          double estimatedTotal = 0;
          try {
            final rateVal = double.tryParse(rateCtrl.text) ?? 0;
            if (hirePeriod == 'hourly') {
              hireUnits = int.tryParse(hoursCtrl.text) ?? 0;
            } else {
              final start = DateTime.tryParse(startCtrl.text);
              final end = DateTime.tryParse(returnCtrl.text);
              if (start != null && end != null && end.isAfter(start)) {
                final secs = end.difference(start).inSeconds;
                final per = {
                  'daily': 86400,
                  'weekly': 604800,
                  'monthly': 2592000
                }[hirePeriod] ??
                    86400;
                hireUnits = (secs / per).ceil().clamp(1, 999999);
              }
            }
            estimatedTotal = rateVal * hireUnits;
          } catch (_) {}

          final unitWord = {
            'hourly': hireUnits == 1 ? 'hour' : 'hours',
            'daily': hireUnits == 1 ? 'day' : 'days',
            'weekly': hireUnits == 1 ? 'week' : 'weeks',
            'monthly': hireUnits == 1 ? 'month' : 'months'
          }[hirePeriod] ??
              'units';

          return Padding(
            padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: bottomInset + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.assignment_turned_in_rounded,
                        color: hcIndigo),
                    const SizedBox(width: 8),
                    const Text('Hire out device',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18)),
                  ]),
                  const SizedBox(height: 6),
                  Text(dev['name']?.toString() ?? '—',
                      style: TextStyle(
                          fontSize: 13, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  // Hire-to toggle
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'patient',
                          icon: Icon(Icons.person_rounded),
                          label: Text('Patient')),
                      ButtonSegment(
                          value: 'facility',
                          icon: Icon(Icons.local_hospital_rounded),
                          label: Text('Facility')),
                    ],
                    selected: {hireToType},
                    onSelectionChanged: (s) =>
                        setSheetState(() => hireToType = s.first),
                  ),
                  const SizedBox(height: 12),
                  if (hireToType == 'patient')
                    DropdownButtonFormField<int>(
                      value: patientId,
                      decoration: const InputDecoration(
                          labelText: 'Patient *'),
                      items: patients
                          .map((p) => DropdownMenuItem<int>(
                                value: p['id'] as int?,
                                child: Text(
                                    (p['patient_name'] ??
                                            p['user']?['full_name'] ??
                                            '#${p['id']}')
                                        .toString(),
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setSheetState(() => patientId = v),
                    )
                  else
                    TextField(
                        controller: facilityCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Facility / homecare name *',
                            prefixIcon:
                                Icon(Icons.local_hospital_rounded))),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: hirePeriod,
                    decoration: const InputDecoration(
                        labelText: 'Billing period'),
                    items: _periodOptions
                        .map((e) => DropdownMenuItem(
                            value: e.$1, child: Text(e.$2)))
                        .toList(),
                    onChanged: (v) {
                      final newPeriod = v ?? 'daily';
                      final rateKey = '${newPeriod}_rate';
                      final devRate = dev[rateKey];
                      if (devRate != null) {
                        rateCtrl.text = devRate.toString();
                      }
                      setSheetState(() => hirePeriod = newPeriod);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: rateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                          labelText: 'Rate',
                          prefixText: 'KSh ',
                          suffixText: '/ ${_periodShort(hirePeriod)}')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: startCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Start date *',
                          prefixIcon: Icon(Icons.play_arrow_rounded))),
                  const SizedBox(height: 10),
                  if (hirePeriod == 'hourly')
                    TextField(
                        controller: hoursCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Number of hours *',
                            suffixText: 'hrs'))
                  else
                    TextField(
                        controller: returnCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Expected return *',
                            prefixIcon: Icon(Icons.event_rounded))),
                  const SizedBox(height: 10),
                  TextField(
                      controller: depositCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Deposit (refundable)',
                          prefixText: 'KSh ')),
                  const SizedBox(height: 10),
                  TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes')),
                  // Charge calculator
                  if (hireUnits > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: hcTeal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16)),
                      child: Column(children: [
                        Row(children: [
                          const Icon(Icons.calculate_rounded,
                              size: 16, color: hcTeal),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$hireUnits $unitWord × ${hcMoney(double.tryParse(rateCtrl.text) ?? 0)}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            hcMoney(estimatedTotal),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: hcTeal),
                          ),
                        ]),
                        if (depositCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '+ ${hcMoney(double.tryParse(depositCtrl.text) ?? 0)} refundable deposit · collect ${hcMoney(estimatedTotal + (double.tryParse(depositCtrl.text) ?? 0))} up front',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                        ],
                      ]),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: hcIndigo),
                      onPressed: saving
                          ? null
                          : () async {
                              if (hireToType == 'patient' &&
                                  patientId == null) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: Text('Pick a patient.')));
                                return;
                              }
                              if (hireToType == 'facility' &&
                                  facilityCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Enter the facility name.')));
                                return;
                              }
                              if (startCtrl.text.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Pick a start date.')));
                                return;
                              }
                              setSheetState(() => saving = true);
                              try {
                                final dio = ref.read(dioProvider);
                                final payload = <String, dynamic>{
                                  'hire_to_type': hireToType,
                                  'patient': hireToType == 'patient'
                                      ? patientId
                                      : null,
                                  'facility_name': hireToType == 'facility'
                                      ? facilityCtrl.text.trim()
                                      : '',
                                  'hire_period': hirePeriod,
                                  if (rateCtrl.text.isNotEmpty)
                                    'hire_rate':
                                        double.tryParse(rateCtrl.text),
                                  if (depositCtrl.text.isNotEmpty)
                                    'deposit':
                                        double.tryParse(depositCtrl.text),
                                  'assigned_at': DateTime.tryParse(
                                          startCtrl.text)
                                      ?.toUtc()
                                      .toIso8601String(),
                                  if (notesCtrl.text.trim().isNotEmpty)
                                    'notes': notesCtrl.text.trim(),
                                };
                                if (hirePeriod == 'hourly') {
                                  final hrs = int.tryParse(hoursCtrl.text) ??
                                      1;
                                  final start =
                                      DateTime.tryParse(startCtrl.text);
                                  if (start != null) {
                                    payload['expected_return_at'] = start
                                        .add(Duration(hours: hrs))
                                        .toUtc()
                                        .toIso8601String();
                                  }
                                } else if (returnCtrl.text.isNotEmpty) {
                                  payload['expected_return_at'] =
                                      DateTime.tryParse(returnCtrl.text)
                                          ?.toUtc()
                                          .toIso8601String();
                                }
                                await dio.post(
                                    '/homecare/devices/${dev['id']}/assign/',
                                    data: payload);
                                ref.invalidate(_devicesProvider);
                                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Device hired out.'),
                                          backgroundColor: hcGreen));
                                }
                              } catch (e) {
                                setSheetState(() => saving = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Failed to assign.'),
                                          backgroundColor: hcRed));
                                }
                              }
                            },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Hire out'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openAssignFromFab(BuildContext context) {
    final data = ref.read(_devicesProvider).valueOrNull;
    if (data == null) return;
    final devices = (data['devices'] as List).cast<Map>();
    final available = devices.where(_isAvailable).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No available devices to assign.')));
      return;
    }
    // Pick the first available device and open the assign dialog
    _openAssign(context, available.first);
  }

  // ── Return device dialog ──
  void _openReturn(BuildContext context, Map dev) {
    final chargeCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool saving = false;
    String condition = 'Good';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('Return device'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(dev['name']?.toString() ?? '—',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: condition,
                decoration: const InputDecoration(
                    labelText: 'Return condition'),
                items: _conditionOptions
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) =>
                    setSheetState(() => condition = v ?? 'Good'),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: chargeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Total hire charge (KSh)',
                      prefixText: 'KSh ',
                      helperText:
                          'Leave blank to auto-calculate from duration × rate')),
              const SizedBox(height: 10),
              TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes')),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: hcGreen),
                onPressed: saving
                    ? null
                    : () async {
                        setSheetState(() => saving = true);
                        try {
                          final dio = ref.read(dioProvider);
                          final payload = <String, dynamic>{
                            'condition': condition,
                            if (notesCtrl.text.trim().isNotEmpty)
                              'notes': notesCtrl.text.trim(),
                          };
                          if (chargeCtrl.text.trim().isNotEmpty) {
                            payload['total_charged'] =
                                double.tryParse(chargeCtrl.text);
                          }
                          await dio.post(
                              '/homecare/devices/${dev['id']}/return_device/',
                              data: payload);
                          ref.invalidate(_devicesProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Device returned.'),
                                    backgroundColor: hcGreen));
                          }
                        } catch (e) {
                          setSheetState(() => saving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text('Failed to return.'),
                                    backgroundColor: hcRed));
                          }
                        }
                      },
                child: const Text('Confirm return')),
          ],
        ),
      ),
    );
  }

  // ── Schedule maintenance dialog ──
  void _openMaintenance(BuildContext context, Map dev) {
    final scheduledCtrl = TextEditingController(text: _nowLocal());
    final notesCtrl = TextEditingController();
    String kind = 'routine';
    bool saving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('Schedule maintenance'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(dev['name']?.toString() ?? '—',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: kind,
                decoration: const InputDecoration(labelText: 'Kind'),
                items: _maintenanceKinds
                    .map((e) =>
                        DropdownMenuItem(value: e.$1, child: Text(e.$2)))
                    .toList(),
                onChanged: (v) =>
                    setSheetState(() => kind = v ?? 'routine'),
              ),
              const SizedBox(height: 10),
              TextField(
                  controller: scheduledCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Scheduled *',
                      prefixIcon: Icon(Icons.event_rounded))),
              const SizedBox(height: 10),
              TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes')),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: hcAmber),
                onPressed: saving
                    ? null
                    : () async {
                        if (scheduledCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text('Pick a date.')));
                          return;
                        }
                        setSheetState(() => saving = true);
                        try {
                          final dio = ref.read(dioProvider);
                          await dio.post(
                              '/homecare/devices/${dev['id']}/schedule_maintenance/',
                              data: {
                                'kind': kind,
                                'scheduled_at': DateTime.tryParse(
                                        scheduledCtrl.text)
                                    ?.toUtc()
                                    .toIso8601String(),
                                if (notesCtrl.text.trim().isNotEmpty)
                                  'notes': notesCtrl.text.trim(),
                              });
                          ref.invalidate(_devicesProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Maintenance scheduled.'),
                                    backgroundColor: hcGreen));
                          }
                        } catch (e) {
                          setSheetState(() => saving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text('Failed to schedule.'),
                                    backgroundColor: hcRed));
                          }
                        }
                      },
                child: const Text('Schedule')),
          ],
        ),
      ),
    );
  }

  // ── History view ──
  Future<void> _openHistory(BuildContext context, Map dev) async {
    List<Map> assignments = [];
    List<Map> maintenance = [];
    bool loading = true;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          if (loading) {
            // Fetch history
            loading = false;
            Future(() async {
              try {
                final dio = ref.read(dioProvider);
                final res = await dio.get('/homecare/devices/${dev['id']}/history/');
                final data = res.data as Map? ?? {};
                assignments = ((data['assignments'] as List?) ?? []).cast<Map>();
                maintenance = ((data['maintenance'] as List?) ?? []).cast<Map>();
              } catch (_) {}
              if (ctx.mounted) setSheetState(() {});
            });
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text('${dev['name'] ?? '—'} — history'),
              content: const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator())),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close')),
              ],
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text('${dev['name'] ?? '—'} — history'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('HIRE ASSIGNMENTS',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: hcSlate)),
                    const SizedBox(height: 6),
                    if (assignments.isEmpty)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No hires yet',
                              style: TextStyle(fontSize: 12.5)))
                    else
                      ...assignments.map((a) => _historyAssignmentRow(a)),
                    const SizedBox(height: 16),
                    const Text('MAINTENANCE',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: hcSlate)),
                    const SizedBox(height: 6),
                    if (maintenance.isEmpty)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('No maintenance recorded',
                              style: TextStyle(fontSize: 12.5)))
                    else
                      ...maintenance.map((m) => _historyMaintenanceRow(m)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }

  Widget _historyAssignmentRow(Map a) {
    final name = a['hire_to_name'] ?? a['patient_name'] ?? a['facility_name'] ?? '—';
    final isFacility = a['hire_to_type'] == 'facility';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(isFacility ? Icons.local_hospital_rounded : Icons.person_rounded,
            size: 14, color: hcBlue),
        const SizedBox(width: 6),
        Expanded(
          child: Text(name,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
        Text(hcDate(a['assigned_at']),
            style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 6),
        Text(
            a['returned_at'] != null
                ? hcDate(a['returned_at'])
                : '— on hire —',
            style: TextStyle(
                fontSize: 11,
                color: a['returned_at'] != null
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : hcGreen)),
        const SizedBox(width: 6),
        Text(hcMoney(a['total_charged'] ?? a['estimated_charge']),
            style: const TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _historyMaintenanceRow(Map m) {
    final mStatus = m['status']?.toString() ?? 'scheduled';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(Icons.build_rounded, size: 14, color: hcAmber),
        const SizedBox(width: 6),
        Expanded(
          child: Text(m['kind_label']?.toString() ?? hcLabel(m['kind']?.toString()),
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
        Text(hcDate(m['scheduled_at']),
            style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 6),
        HcStatusChip(
            label: hcLabel(mStatus),
            color: mStatus == 'completed'
                ? hcGreen
                : mStatus == 'in_progress'
                    ? hcBlue
                    : mStatus == 'cancelled'
                        ? hcRed
                        : hcAmber),
        if (m['cost'] != null) ...[
          const SizedBox(width: 6),
          Text(hcMoney(m['cost']),
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }

  // ── Delete confirmation ──
  void _confirmDelete(BuildContext context, Map dev) {
    bool saving = false;
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete device?'),
          content: Text(
              'This permanently removes ${dev['name'] ?? 'this device'} and its history.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: hcRed),
              onPressed: saving
                  ? null
                  : () async {
                      setSheetState(() => saving = true);
                      try {
                        final dio = ref.read(dioProvider);
                        await dio.delete('/homecare/devices/${dev['id']}/');
                        ref.invalidate(_devicesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Device deleted.'),
                                  backgroundColor: hcGreen));
                        }
                      } catch (e) {
                        setSheetState(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text('Failed to delete.'),
                              backgroundColor: hcRed));
                        }
                      }
                    },
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════ AUDIT LOG ═════════════════
final _auditProvider = FutureProvider.autoDispose((ref) async {
  return hcFetchAll(ref, '/homecare/audit-events/',
      params: {'page_size': 200, 'ordering': '-created_at'});
});

const _auditActions = [
  'create', 'update', 'delete', 'view', 'login', 'export', 'consent_grant', 'consent_revoke'
];

IconData _auditActionIcon(String? a) => switch (a) {
  'create'         => Icons.add_circle_rounded,
  'update'         => Icons.edit_rounded,
  'delete'         => Icons.delete_rounded,
  'view'           => Icons.visibility_rounded,
  'login'          => Icons.login_rounded,
  'export'         => Icons.download_rounded,
  'consent_grant'  => Icons.check_circle_rounded,
  'consent_revoke' => Icons.cancel_rounded,
  _                => Icons.circle_rounded,
};

Color _auditActionColor(String? a) => switch (a) {
  'create'         => hcGreen,
  'update'         => hcBlue,
  'delete'         => hcRed,
  'view'           => hcSlate,
  'login'          => hcTeal,
  'export'         => hcAmber,
  'consent_grant'  => hcGreen,
  'consent_revoke' => hcRed,
  _                => hcSlate,
};

class HomecareAuditScreen extends ConsumerStatefulWidget {
  const HomecareAuditScreen({super.key});

  @override
  ConsumerState<HomecareAuditScreen> createState() => _HomecareAuditScreenState();
}

class _HomecareAuditScreenState extends ConsumerState<HomecareAuditScreen> {
  String _search = '';
  String _filterAction = '';
  DateTime? _filterDate;

  String _actorName(Map e) =>
      (e['actor_name'] ?? e['actor_email'] ?? e['user_name'] ??
       (e['actor_user_id'] != null ? 'user#${e['actor_user_id']}' : 'system'))
      .toString();

  String _actionLabel(Map e) =>
      (e['action'] ?? e['event'] ?? '—').toString();

  String _resourceType(Map e) =>
      (e['object_type'] ?? e['resource_type'] ?? '').toString();

  String _summary(Map e) {
    final method = (e['method'] ?? '').toString().toUpperCase();
    final path = (e['path'] ?? '').toString();
    final objectId = e['object_id'];
    if (method.isEmpty && path.isEmpty && objectId == null) return '';
    return '$method $path${objectId != null ? ' → #$objectId' : ''}';
  }

  DateTime? _createdAt(Map e) =>
      DateTime.tryParse((e['created_at'] ?? e['timestamp'] ?? '').toString())?.toLocal();

  @override
  Widget build(BuildContext context) {
    final audit = ref.watch(_auditProvider);
    final cs = Theme.of(context).colorScheme;
    return HcAsyncBody(
      value: audit,
      onRefresh: () async => ref.refresh(_auditProvider.future),
      builder: (list) {
        final allRows = list.cast<Map>().toList();

        var rows = allRows;
        if (_filterAction.isNotEmpty) {
          rows = rows.where((e) => _actionLabel(e) == _filterAction).toList();
        }
        if (_filterDate != null) {
          rows = rows.where((e) {
            final at = _createdAt(e);
            return at != null &&
                at.year == _filterDate!.year &&
                at.month == _filterDate!.month &&
                at.day == _filterDate!.day;
          }).toList();
        }
        if (_search.isNotEmpty) {
          final q = _search.toLowerCase();
          rows = rows.where((e) {
            final blob = '${_actionLabel(e)} ${_resourceType(e)} ${_actorName(e)} ${_summary(e)}'.toLowerCase();
            return blob.contains(q);
          }).toList();
        }

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _buildHero(cs, allRows.length),
            _buildStats(cs, allRows),
            _buildSearchAndFilters(cs),
            if (rows.isEmpty)
              _buildEmptyState(cs)
            else
              _buildTimeline(cs, rows),
          ],
        );
      },
    );
  }

  // ── Hero ──
  Widget _buildHero(ColorScheme cs, int total) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF334155), Color(0xFF475569), Color(0xFF64748B)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: hcSlate.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 14))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.history_rounded, color: Colors.white, size: 28),
          ),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: hcSlate,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            onPressed: () => _exportCsv(),
            icon: const Icon(Icons.download_rounded, size: 20),
            label: const Text('Export CSV', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 16),
        Text('COMPLIANCE',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
        const SizedBox(height: 4),
        const Text('Audit Log', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Compliance trail of every action taken in your homecare workspace.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13, height: 1.4)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _heroChip(Icons.shield_rounded, 'HIPAA / GDPR ready'),
          _heroChip(Icons.list_alt_rounded, '$total events'),
        ]),
      ]),
    );
  }

  Widget _heroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ── Stats ──
  Widget _buildStats(ColorScheme cs, List<Map> allRows) {
    final actionCounts = <String, int>{};
    for (final e in allRows) {
      final a = _actionLabel(e);
      actionCounts[a] = (actionCounts[a] ?? 0) + 1;
    }
    final topActions = actionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top4 = topActions.take(4).toList();
    if (top4.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: top4.map((entry) {
        final color = _auditActionColor(entry.key);
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: entry.key != top4.last.key ? 8 : 0),
          child: _AuditStatTile(
            icon: _auditActionIcon(entry.key),
            label: entry.key,
            value: '${entry.value}',
            color: color,
            active: _filterAction == entry.key,
            onTap: () => setState(() => _filterAction = _filterAction == entry.key ? '' : entry.key),
          ),
        ));
      }).toList()),
    );
  }

  // ── Search + filters ──
  Widget _buildSearchAndFilters(ColorScheme cs) {
    return Column(children: [
      // Search
      Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'Search…',
            prefixIcon: Icon(Icons.search_rounded, color: cs.onSurfaceVariant, size: 22),
            suffixIcon: _search.isNotEmpty
                ? IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => setState(() => _search = ''))
                : null,
            filled: true, fillColor: Colors.transparent,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            isDense: true, hintStyle: TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant),
          ),
        ),
      ),
      // Action filter chips + date filter
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Row(children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _actionChip(cs, 'All', ''),
                  ..._auditActions.map((a) => _actionChip(cs, a, a)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Date filter
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _filterDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _filterDate = d);
            },
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _filterDate != null ? hcTeal.withValues(alpha: 0.08) : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: _filterDate != null ? Border.all(color: hcTeal.withValues(alpha: 0.3)) : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_month_rounded, size: 16,
                    color: _filterDate != null ? hcTeal : cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  _filterDate != null
                      ? '${_filterDate!.day}/${_filterDate!.month}/${_filterDate!.year}'
                      : 'Date',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: _filterDate != null ? hcTeal : cs.onSurfaceVariant),
                ),
                if (_filterDate != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _filterDate = null),
                    child: Icon(Icons.close_rounded, size: 14, color: hcTeal),
                  ),
                ],
              ]),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _actionChip(ColorScheme cs, String label, String action) {
    final active = _filterAction == action;
    final color = action.isEmpty ? hcSlate : _auditActionColor(action);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: active ? Colors.white : cs.onSurfaceVariant)),
        selected: active,
        onSelected: (v) => setState(() => _filterAction = v ? action : ''),
        selectedColor: color,
        backgroundColor: cs.surfaceContainerHighest,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        showCheckmark: false,
      ),
    );
  }

  // ── Timeline ──
  Widget _buildTimeline(ColorScheme cs, List<Map> rows) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: hcSlate.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.format_list_bulleted_rounded, color: hcSlate, size: 18)),
          const SizedBox(width: 10),
          const Text('Recent activity', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(width: 6),
          Text('${rows.length} entries', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        ]),
        const SizedBox(height: 16),
        ...rows.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final isLast = i == rows.length - 1;
          return _TimelineItem(
            event: e,
            isLast: isLast,
            actorName: _actorName(e),
            actionLabel: _actionLabel(e),
            resourceType: _resourceType(e),
            summary: _summary(e),
            createdAt: _createdAt(e),
          );
        }),
      ]),
    );
  }

  // ── Empty state ──
  Widget _buildEmptyState(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [hcSlate.withValues(alpha: 0.12), hcSlate.withValues(alpha: 0.04)]),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_rounded, size: 38, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 16),
            const Text('No audit entries', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 6),
            Text('Start using the system to populate this log.', style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  // ── Export CSV ──
  void _exportCsv() async {
    final audit = ref.read(_auditProvider).valueOrNull;
    if (audit == null) return;
    var rows = audit.cast<Map>().toList();
    if (_filterAction.isNotEmpty) {
      rows = rows.where((e) => _actionLabel(e) == _filterAction).toList();
    }
    if (_filterDate != null) {
      rows = rows.where((e) {
        final at = _createdAt(e);
        return at != null && at.year == _filterDate!.year && at.month == _filterDate!.month && at.day == _filterDate!.day;
      }).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      rows = rows.where((e) {
        final blob = '${_actionLabel(e)} ${_resourceType(e)} ${_actorName(e)} ${_summary(e)}'.toLowerCase();
        return blob.contains(q);
      }).toList();
    }

    final header = ['When', 'Actor', 'Action', 'Resource', 'Summary'];
    String esc(dynamic v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    final lines = [header.map(esc).join(',')];
    for (final e in rows) {
      lines.add([
        e['created_at'] ?? '',
        _actorName(e),
        _actionLabel(e),
        _resourceType(e),
        _summary(e),
      ].map(esc).join(','));
    }
    final csv = lines.join('\n');

    final messenger = ScaffoldMessenger.of(context);
    try {
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/audit-export-${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);
      await share_plus.Share.shareXFiles([share_plus.XFile(file.path, mimeType: 'text/csv')], text: 'Audit log export');
    } catch (_) {
      // Fallback: share as text
      try {
        await share_plus.Share.share(csv, subject: 'Audit log export');
      } catch (_) {
        if (mounted) {
          messenger.showSnackBar(const SnackBar(content: Text('Export failed'), backgroundColor: hcRed));
        }
      }
    }
    if (mounted) {
      messenger.showSnackBar(SnackBar(
        content: Text('Exported ${rows.length} entries'),
        backgroundColor: hcGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }
}

// ── Audit stat tile ──
class _AuditStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _AuditStatTile({required this.icon, required this.label, required this.value, required this.color, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.08) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: active ? Border.all(color: color.withValues(alpha: 0.35), width: 1.5) : null,
        boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, letterSpacing: 0.3),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Timeline item ──
class _TimelineItem extends StatelessWidget {
  final Map event;
  final bool isLast;
  final String actorName;
  final String actionLabel;
  final String resourceType;
  final String summary;
  final DateTime? createdAt;
  const _TimelineItem({
    required this.event, required this.isLast, required this.actorName,
    required this.actionLabel, required this.resourceType, required this.summary, required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _auditActionColor(actionLabel);
    final icon = _auditActionIcon(actionLabel);

    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Timeline dot + line
        SizedBox(
          width: 36,
          child: Column(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Icon(icon, size: 15, color: Colors.white),
            ),
            if (!isLast)
              Expanded(child: Container(
                width: 2,
                margin: const EdgeInsets.only(top: 2),
                color: cs.outlineVariant.withValues(alpha: 0.4),
              )),
          ]),
        ),
        const SizedBox(width: 10),
        // Content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Action + resource chip + date
              Row(children: [
                Text(actionLabel, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: cs.onSurface)),
                const SizedBox(width: 6),
                if (resourceType.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(5)),
                    child: Text(resourceType, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                  ),
                const Spacer(),
                if (createdAt != null)
                  Text(timeago.format(createdAt!), style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant)),
              ]),
              const SizedBox(height: 3),
              // Actor
              Row(children: [
                Icon(Icons.person_rounded, size: 12, color: cs.onSurfaceVariant),
                const SizedBox(width: 3),
                Text(actorName, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
              ]),
              // Summary
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(summary, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontFamily: 'monospace'),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}

// ═════════════════ REPORTS ═════════════════
final _reportsProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final res = await dio.get('/homecare/dashboard/summary/');
  return res.data as Map<String, dynamic>;
});

class HomecareReportsScreen extends ConsumerWidget {
  const HomecareReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(_reportsProvider);
    return HcAsyncBody(
      value: reports,
      onRefresh: () async => ref.refresh(_reportsProvider.future),
      builder: (d) {
        final kpis = (d['kpis'] as Map?) ?? {};
        final doses = (d['today_doses'] as Map?) ?? {};
        final trend = ((d['adherence_trend'] as List?) ?? []).cast<Map>();
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: 'ANALYTICS',
              title: 'Reports',
              subtitle: 'Operational & clinical performance',
              icon: Icons.insights_rounded,
              chips: [
                HcHeroChip(
                    icon: Icons.pie_chart_rounded,
                    label: 'Adherence ${kpis['adherence_today'] ?? '—'}%'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.3,
                children: [
                  HcKpi(
                      label: 'Active patients',
                      value: '${kpis['active_patients'] ?? 0}',
                      icon: Icons.people_rounded,
                      color: hcTeal),
                  HcKpi(
                      label: 'Caregivers',
                      value: '${kpis['caregivers_total'] ?? 0}',
                      icon: Icons.medical_services_rounded,
                      color: hcBlue),
                  HcKpi(
                      label: 'Doses today',
                      value: '${doses['total'] ?? 0}',
                      hint:
                          '${doses['taken'] ?? 0} taken · ${doses['missed'] ?? 0} missed',
                      icon: Icons.medication_rounded,
                      color: hcPurple),
                  HcKpi(
                      label: 'Open claims',
                      value: '${kpis['open_claims'] ?? 0}',
                      icon: Icons.gavel_rounded,
                      color: hcAmber),
                ],
              ),
            ),
            const SizedBox(height: 14),
            HcPanel(
              title: '7-day adherence trend',
              icon: Icons.show_chart_rounded,
              color: hcTeal,
              child: Column(
                children: trend
                    .map((t) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            SizedBox(
                                width: 84,
                                child: Text(hcDate(t['date']),
                                    style:
                                        const TextStyle(fontSize: 11.5))),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ((t['rate'] as num?) ?? 0) / 100,
                                  minHeight: 8,
                                  color: hcTeal,
                                ),
                              ),
                            ),
                            SizedBox(
                                width: 48,
                                child: Text('${t['rate'] ?? 0}%',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700))),
                          ]),
                        ))
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═════════════════ HR (dashboard-lite) ═════════════════
final _hrProvider = FutureProvider.autoDispose((ref) async {
  final dio = ref.read(dioProvider);
  final results = await Future.wait([
    dio.get('/homecare/hr/dashboard/'),
    hcFetchAll(ref, '/homecare/hr/employees/', params: {'page_size': 100}),
    hcFetchAll(ref, '/homecare/hr/leave-requests/',
        params: {'page_size': 50}),
    hcFetchAll(ref, '/homecare/hr/timesheets/', params: {'page_size': 50}),
    hcFetchAll(ref, '/homecare/hr/payroll/', params: {'page_size': 50}),
    hcFetchAll(ref, '/homecare/hr/jobs/', params: {'page_size': 50}),
    hcFetchAll(ref, '/homecare/hr/training-programs/',
        params: {'page_size': 50}),
  ]);
  return {
    'dash': (results[0] as dynamic).data as Map<String, dynamic>,
    'employees': results[1] as List,
    'leaves': results[2] as List,
    'timesheets': results[3] as List,
    'payroll': results[4] as List,
    'jobs': results[5] as List,
    'training': results[6] as List,
  };
});

class HomecareHrScreen extends ConsumerStatefulWidget {
  const HomecareHrScreen({super.key});

  @override
  ConsumerState<HomecareHrScreen> createState() => _HomecareHrScreenState();
}

class _HomecareHrScreenState extends ConsumerState<HomecareHrScreen> {
  final ScrollController _scroll = ScrollController();
  final Map<String, GlobalKey> _keys = {};

  GlobalKey _key(String tag) => _keys.putIfAbsent(tag, () => GlobalKey());

  void _scrollTo(String tag) {
    final ctx = _keys[tag]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          alignment: 0.0);
    }
  }

  Color _webColor(String? name) => switch (name) {
        'teal' => hcTeal,
        'blue' || 'info' => hcBlue,
        'purple' => hcPurple,
        'orange' || 'amber' || 'warning' => hcAmber,
        'pink' => const Color(0xFFEC4899),
        'indigo' => hcIndigo,
        'green' || 'success' => hcGreen,
        'cyan' => const Color(0xFF06B6D4),
        'red' || 'error' => hcRed,
        _ => hcSlate,
      };

  Color _daysColor(int days) {
    if (days < 0) return hcRed;
    if (days <= 14) return hcAmber;
    return hcGreen;
  }

  @override
  Widget build(BuildContext context) {
    final hr = ref.watch(_hrProvider);
    return HcAsyncBody(
      value: hr,
      onRefresh: () async => ref.refresh(_hrProvider.future),
      builder: (d) {
        final dash = (d['dash'] as Map?) ?? const <String, dynamic>{};
        final employees = (d['employees'] as List).cast<Map>();
        final leaves = (d['leaves'] as List).cast<Map>();
        final timesheets = (d['timesheets'] as List).cast<Map>();
        final payroll = (d['payroll'] as List).cast<Map>();
        final jobs = (d['jobs'] as List).cast<Map>();
        final training = (d['training'] as List).cast<Map>();
        final departments = (dash['departments'] as List?) ?? const [];
        final funnelRaw = (dash['funnel'] as Map?) ?? const {};
        final recentHires = (dash['recent_hires'] as List?) ?? const [];
        final compliance = (dash['compliance'] as List?) ?? const [];
        return ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HcHero(
              eyebrow: 'ADMIN & MANAGEMENT · HR',
              title: 'Human Resources',
              subtitle:
                  'Manage the full employee lifecycle — recruitment, onboarding, scheduling, payroll, compliance & performance.',
              icon: Icons.badge_rounded,
              gradient: const [
                Color(0xFF7C2D12),
                Color(0xFFC2410C),
                Color(0xFFEA580C)
              ],
              chips: [
                HcHeroChip(
                    icon: Icons.groups_rounded,
                    label:
                        '${dash['total_staff'] ?? dash['total_employees'] ?? employees.length} staff'),
                HcHeroChip(
                    icon: Icons.work_outline_rounded,
                    label: '${dash['open_positions'] ?? dash['open_jobs'] ?? 0} open roles'),
                HcHeroChip(
                    icon: Icons.person_add_rounded,
                    label: '${dash['onboarding'] ?? 0} onboarding'),
                HcHeroChip(
                    icon: Icons.payments_rounded,
                    label: '${hcMoney(dash['monthly_payroll'])}/mo'),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.2,
                children: [
                  HcKpi(
                      label: 'Active Employees',
                      value:
                          '${dash['total_staff'] ?? dash['total_employees'] ?? employees.length}',
                      icon: Icons.groups_rounded,
                      color: hcTeal,
                      hint:
                          '${dash['full_time'] ?? 0} full-time · ${dash['part_time'] ?? 0} part-time'),
                  HcKpi(
                      label: 'Open Applications',
                      value: '${dash['applicants'] ?? 0}',
                      icon: Icons.account_circle_outlined,
                      color: hcBlue,
                      hint: '${dash['new_applicants'] ?? 0} this week'),
                  HcKpi(
                      label: 'On Leave Today',
                      value: '${dash['on_leave'] ?? dash['on_leave_today'] ?? 0}',
                      icon: Icons.event_busy_rounded,
                      color: hcAmber,
                      hint:
                          '${dash['pending_leaves'] ?? dash['pending_leave_requests'] ?? 0} requests pending'),
                  HcKpi(
                      label: 'Compliance Score',
                      value: '${dash['compliance_score'] ?? 0}%',
                      icon: Icons.verified_user_rounded,
                      color: hcPurple,
                      hint:
                          "${((dash['compliance_trend'] ?? 0) as num) >= 0 ? '↑' : '↓'} ${dash['compliance_trend'] ?? 0}% vs last month"),
                ],
              ),
            ),
            const SizedBox(height: 14),
            HcPanel(
              title: 'Quick Actions',
              subtitle: 'Jump to a task',
              icon: Icons.bolt_rounded,
              color: hcAmber,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in <(String, IconData, String)>[
                    ('Add Employee', Icons.person_add_rounded, 'employees'),
                    ('Post Job', Icons.work_outline_rounded, 'jobs'),
                    ('Approve Leave', Icons.event_available_rounded, 'leaves'),
                    ('Run Payroll', Icons.payments_rounded, 'payroll'),
                    ('Clock-in Report', Icons.schedule_rounded, 'timesheets'),
                    ('Compliance', Icons.gavel_rounded, 'compliance'),
                  ])
                    OutlinedButton.icon(
                      onPressed: () => _scrollTo(a.$3),
                      icon: Icon(a.$2, size: 18),
                      label: Text(a.$1),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                ],
              ),
            ),
            HcPanel(
              title: 'Department Headcount',
              icon: Icons.account_tree_rounded,
              color: hcBlue,
              child: departments.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: Text('No department data.')),
                    )
                  : Column(
                      children: departments.map<Widget>((dep) {
                        final name = (dep['name'] ?? '—').toString();
                        final count = dep['count'] ?? 0;
                        final pct = (dep['pct'] ?? 0).toDouble();
                        final color = _webColor((dep['color'] ?? '').toString());
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            Icon(Icons.groups_rounded, size: 18, color: color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(name,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                            Text('$count',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 80,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (pct / 100).clamp(0.0, 1.0),
                                  color: color,
                                  backgroundColor: color.withValues(alpha: 0.12),
                                  minHeight: 5,
                                ),
                              ),
                            ),
                          ]),
                        );
                      }).toList(),
                    ),
            ),
            HcPanel(
              key: _key('compliance'),
              title: 'Upcoming Compliance Deadlines',
              subtitle: 'Licences, certifications & training expiry',
              icon: Icons.gavel_rounded,
              color: hcRed,
              child: compliance.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                          child: Text('All clear — no pending deadlines.')),
                    )
                  : Column(
                      children: compliance.map<Widget>((c) {
                        final days = (c['days_left'] ?? 0) as num;
                        final d = days.toInt();
                        final color = _daysColor(d);
                        final type = (c['type'] ?? '').toString();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(
                              d < 0
                                  ? Icons.error_rounded
                                  : Icons.schedule_rounded,
                              color: color,
                              size: 20),
                          title: Text((c['name'] ?? '—').toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: Text(
                              '${type.isEmpty ? "Compliance" : hcLabel(type)} · ${(c['employee'] ?? '—').toString()}',
                              style: const TextStyle(fontSize: 11)),
                          trailing: HcStatusChip(
                            label: d < 0 ? '${d.abs()}d overdue' : '${d}d left',
                            color: color,
                          ),
                        );
                      }).toList(),
                    ),
            ),
            HcPanel(
              title: 'Recruitment Pipeline',
              subtitle: 'Applicants by stage',
              icon: Icons.person_add_alt_rounded,
              color: hcPurple,
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.28,
                children: [
                  for (final s in <(String, IconData, Color, String)>[
                    ('Applied', Icons.mail_outline_rounded, hcBlue, 'applied'),
                    ('Screening', Icons.person_search_rounded, hcTeal,
                        'screening'),
                    ('Interview', Icons.record_voice_over_rounded, hcAmber,
                        'interview'),
                    ('Offer', Icons.handshake_rounded, hcPurple, 'offer'),
                    ('Hired', Icons.person_outline_rounded, hcGreen, 'hired'),
                    ('Declined', Icons.person_remove_rounded, hcRed, 'declined'),
                  ])
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: s.$3.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(s.$2, color: s.$3, size: 20),
                          const SizedBox(height: 4),
                          Text('${funnelRaw[s.$4] ?? 0}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  color: s.$3)),
                          Text(s.$1,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            HcPanel(
              title: 'Recent Hires',
              subtitle: 'Latest additions to the team',
              icon: Icons.person_add_alt_1_rounded,
              color: hcGreen,
              child: recentHires.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: Text('No recent hires.')),
                    )
                  : Column(
                      children: recentHires.map<Widget>((h) {
                        final name = (h['name'] ?? '—').toString();
                        final status = (h['status'] ?? 'active').toString();
                        final color = status == 'onboarding'
                            ? hcAmber
                            : status == 'inactive'
                                ? hcSlate
                                : hcGreen;
                        final role = (h['role'] ?? '').toString();
                        final dept = (h['department'] ?? '').toString();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: HcAvatar(name: name, size: 34, color: hcGreen),
                          title: Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: Text(
                              '${role.isEmpty ? "—" : hcLabel(role)} · ${dept.isEmpty ? "—" : dept}',
                              style: const TextStyle(fontSize: 11)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(hcDate(h['start_date']),
                                  style: const TextStyle(fontSize: 10)),
                              const SizedBox(height: 2),
                              HcStatusChip(label: hcLabel(status), color: color),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            HcPanel(
              key: _key('leaves'),
              title: 'Leave requests',
              subtitle: 'Latest submissions',
              icon: Icons.beach_access_rounded,
              color: hcAmber,
              child: leaves.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: Text('No leave requests.')),
                    )
                  : Column(
                      children: leaves.take(10).map<Widget>((l) {
                        final status = (l['status'] ?? '').toString();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.beach_access_rounded,
                              color: hcAmber, size: 20),
                          title: Text(
                              (l['employee_name'] ?? l['employee'] ?? '—')
                                  .toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          subtitle: Text(
                              '${hcLabel((l['leave_type'] ?? '').toString())} · ${hcDate(l['start_date'])} → ${hcDate(l['end_date'])}',
                              style: const TextStyle(fontSize: 11)),
                          trailing: HcStatusChip(
                              label: hcLabel(status),
                              color: status == 'approved'
                                  ? hcGreen
                                  : status == 'rejected'
                                      ? hcRed
                                      : hcAmber),
                        );
                      }).toList(),
                    ),
            ),
            HcPanel(
              key: _key('timesheets'),
              title: 'Timesheets',
              subtitle: 'Recent submissions',
              icon: Icons.schedule_rounded,
              color: hcBlue,
              child: timesheets.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: Text('No timesheets.')),
                    )
                  : Column(
                      children: timesheets.take(10).map<Widget>((t) {
                        final status = (t['status'] ?? '').toString();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.schedule_rounded,
                              color: hcBlue, size: 20),
                          title: Text(
                              (t['employee_name'] ?? t['employee'] ?? '—')
                                  .toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          subtitle: Text(
                              '${hcDate(t['period_start'] ?? t['week_start'] ?? t['date'])} · ${t['total_hours'] ?? t['hours'] ?? '—'} hrs',
                              style: const TextStyle(fontSize: 11)),
                          trailing: HcStatusChip(
                              label: hcLabel(status),
                              color: status == 'approved'
                                  ? hcGreen
                                  : hcAmber),
                        );
                      }).toList(),
                    ),
            ),
            HcPanel(
              key: _key('payroll'),
              title: 'Payroll',
              subtitle: 'Recent entries',
              icon: Icons.payments_rounded,
              color: hcGreen,
              child: payroll.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: Text('No payroll entries.')),
                    )
                  : Column(
                      children: payroll.take(8).map<Widget>((p) {
                        final status = (p['status'] ?? '').toString();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.payments_rounded,
                              color: hcGreen, size: 20),
                          title: Text(
                              (p['employee_name'] ?? p['employee'] ?? '—')
                                  .toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          subtitle: Text(
                              '${hcDate(p['period_start'] ?? p['pay_date'])} · net ${hcMoney(p['net_pay'] ?? p['net_salary'] ?? p['amount'])}',
                              style: const TextStyle(fontSize: 11)),
                          trailing: HcStatusChip(
                              label: hcLabel(status.isEmpty ? 'draft' : status),
                              color: status == 'paid'
                                  ? hcGreen
                                  : hcAmber),
                        );
                      }).toList(),
                    ),
            ),
            HcPanel(
              key: _key('jobs'),
              title: 'Recruitment',
              subtitle: 'Open job postings',
              icon: Icons.work_outline_rounded,
              color: hcBlue,
              child: jobs.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: Text('No job openings.')),
                    )
                  : Column(
                      children: jobs.take(8).map<Widget>((j) {
                        final status = (j['status'] ?? '').toString();
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.work_outline_rounded,
                              color: hcBlue, size: 20),
                          title: Text(
                              (j['title'] ?? '—').toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          subtitle: Text(
                              '${hcLabel((j['department'] ?? '').toString())}'
                              '${j['applicants_count'] != null ? ' · ${j['applicants_count']} applicants' : ''}',
                              style: const TextStyle(fontSize: 11)),
                          trailing: HcStatusChip(
                              label: hcLabel(
                                  status.isEmpty ? 'open' : status),
                              color: status == 'closed'
                                  ? hcSlate
                                  : hcGreen),
                        );
                      }).toList(),
                    ),
            ),
            HcPanel(
              title: 'Training programs',
              icon: Icons.school_rounded,
              color: hcPurple,
              child: training.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: Text('No training programs.')),
                    )
                  : Column(
                      children: training.take(8).map<Widget>((t) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.school_rounded,
                              color: hcPurple, size: 20),
                          title: Text(
                              (t['name'] ?? t['title'] ?? '—').toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                          subtitle: Text(
                              '${hcDate(t['start_date'])}${t['participants_count'] != null ? ' · ${t['participants_count']} enrolled' : ''}',
                              style: const TextStyle(fontSize: 11)),
                        );
                      }).toList(),
                    ),
            ),
            HcPanel(
              key: _key('employees'),
              title: 'Employees',
              icon: Icons.badge_rounded,
              color: hcTeal,
              child: employees.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: Text('No employee records.')),
                    )
                  : Column(
                      children: employees
                          .take(30)
                          .map<Widget>((emp) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: HcAvatar(
                                    name: (emp['full_name'] ??
                                            emp['name'] ??
                                            emp['user']?['full_name'])
                                        ?.toString(),
                                    size: 36,
                                    color: hcTeal),
                                title: Text(
                                    (emp['full_name'] ??
                                            emp['name'] ??
                                            emp['user']?['full_name'] ??
                                            '—')
                                        .toString(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                                subtitle: Text(
                                    '${hcLabel((emp['job_title'] ?? emp['position'] ?? '').toString())}'
                                    '${(emp['department'] ?? '').toString().isNotEmpty ? ' · ${emp['department']}' : ''}',
                                    style: const TextStyle(fontSize: 11)),
                                trailing: HcStatusChip(
                                    label: hcLabel(
                                        (emp['status'] ?? 'active')
                                            .toString()),
                                    color: (emp['status'] ?? 'active') ==
                                            'active'
                                        ? hcGreen
                                        : hcSlate),
                              ))
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}
