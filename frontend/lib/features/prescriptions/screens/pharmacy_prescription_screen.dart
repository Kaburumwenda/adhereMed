import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../auth/providers/auth_provider.dart';
import '../../inventory/models/stock_model.dart';
import '../../inventory/repository/inventory_repository.dart';

// ─── Data class for a prescription item row ────────────────────────────────

class _RxItem {
  final TextEditingController medicationName;
  final TextEditingController dosage;
  final TextEditingController frequency;
  final TextEditingController duration;
  final TextEditingController quantity;
  final TextEditingController instructions;
  int? stockId;

  _RxItem({
    String name = '',
    String dos = '',
    String freq = '',
    String dur = '',
    String qty = '1',
    String inst = '',
    this.stockId,
  })  : medicationName = TextEditingController(text: name),
        dosage = TextEditingController(text: dos),
        frequency = TextEditingController(text: freq),
        duration = TextEditingController(text: dur),
        quantity = TextEditingController(text: qty),
        instructions = TextEditingController(text: inst);

  factory _RxItem.fromJson(Map<String, dynamic> j) => _RxItem(
        name: j['medication_name'] ?? '',
        dos: j['dosage'] ?? '',
        freq: j['frequency'] ?? '',
        dur: j['duration'] ?? '',
        qty: '${j['quantity'] ?? 1}',
        inst: j['instructions'] ?? '',
        stockId: j['stock_id'],
      );

  void dispose() {
    medicationName.dispose();
    dosage.dispose();
    frequency.dispose();
    duration.dispose();
    quantity.dispose();
    instructions.dispose();
  }

  Map<String, dynamic> toJson() => {
        'medication_name': medicationName.text.trim(),
        'stock_id': stockId,
        'dosage': dosage.text.trim(),
        'frequency': frequency.text.trim(),
        'duration': duration.text.trim(),
        'quantity': int.tryParse(quantity.text.trim()) ?? 1,
        'instructions': instructions.text.trim(),
      };
}

// ─── Repository calls ──────────────────────────────────────────────────────

class _PharmacyRxRepository {
  final _dio = ApiClient.instance;

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final r = await _dio.post('/prescriptions/pharmacy-rx/', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> data) async {
    final r = await _dio.put('/prescriptions/pharmacy-rx/$id/', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDetail(int id) async {
    final r = await _dio.get('/prescriptions/pharmacy-rx/$id/');
    return r.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getList({
    int page = 1,
    String? search,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null) params['status'] = status;
    if (dateFrom != null) params['date_from'] = DateFormat('yyyy-MM-dd').format(dateFrom);
    if (dateTo != null) params['date_to'] = DateFormat('yyyy-MM-dd').format(dateTo);
    final r = await _dio.get('/prescriptions/pharmacy-rx/', queryParameters: params);
    final data = r.data;
    if (data is List) return data.cast();
    return ((data['results'] as List?) ?? []).cast();
  }
}

// ─── Screens ───────────────────────────────────────────────────────────────

/// List of pharmacy prescriptions.
class PharmacyPrescriptionListScreen extends ConsumerStatefulWidget {
  const PharmacyPrescriptionListScreen({super.key});

  @override
  ConsumerState<PharmacyPrescriptionListScreen> createState() =>
      _PharmacyPrescriptionListScreenState();
}

class _PharmacyPrescriptionListScreenState
    extends ConsumerState<PharmacyPrescriptionListScreen> {
  final _repo = _PharmacyRxRepository();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  // Filters
  String? _statusFilter;      // null = all
  String? _datePreset;        // 'today' | 'week' | 'month' | 'year' | null
  DateTime? _dateFrom;
  DateTime? _dateTo;

  // ── derived analytics (computed from _items) ──────────────────
  int get _total => _items.length;
  int get _activeCount    => _items.where((r) => r['status'] == 'active').length;
  int get _dispensedCount => _items.where((r) => r['status'] == 'dispensed').length;
  int get _cancelledCount => _items.where((r) => r['status'] == 'cancelled').length;
  int get _totalMeds => _items.fold(0, (s, r) => s + ((r['items'] as List?)?.length ?? 0));

  bool get _hasDateFilter => _dateFrom != null || _dateTo != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load({String? search}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.getList(
        search: search,
        status: _statusFilter,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
      );
      if (mounted) setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: (_dateFrom != null && _dateTo != null)
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 30)), end: now),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _datePreset = null;  // custom range clears preset
        _dateFrom = picked.start;
        _dateTo = picked.end;
      });
      _load(search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim());
    }
  }

  void _clearDateFilter() {
    setState(() { _dateFrom = null; _dateTo = null; _datePreset = null; });
    _load(search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim());
  }

  void _applyDatePreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime from;
    DateTime to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (preset) {
      case 'today':
        from = today;
        break;
      case 'week':
        from = today.subtract(Duration(days: today.weekday - 1)); // Mon
        break;
      case 'month':
        from = DateTime(now.year, now.month, 1);
        break;
      case 'year':
        from = DateTime(now.year, 1, 1);
        break;
      default:
        return;
    }
    // Toggle off if same preset tapped again
    if (_datePreset == preset) {
      _clearDateFilter();
      return;
    }
    setState(() {
      _datePreset = preset;
      _dateFrom = from;
      _dateTo = to;
    });
    _load(search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.medication_liquid_outlined,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pharmacy Prescriptions',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('Manage walk-in patient prescriptions',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push('/pharmacy-rx/new'),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Prescription'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Stat Cards ───────────────────────────────────────────────────
          if (!_loading) ...
            [
              SizedBox(
                height: 82,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _StatCard(
                      label: 'Total',
                      value: '$_total',
                      icon: Icons.receipt_long_outlined,
                      color: AppColors.primary,
                      isSelected: _statusFilter == null,
                      onTap: () {
                        setState(() => _statusFilter = null);
                        _load(search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim());
                      },
                    ),
                    _StatCard(
                      label: 'Active',
                      value: '$_activeCount',
                      icon: Icons.check_circle_outline,
                      color: AppColors.primary,
                      isSelected: _statusFilter == 'active',
                      onTap: () {
                        setState(() => _statusFilter = _statusFilter == 'active' ? null : 'active');
                        _load(search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim());
                      },
                    ),
                    _StatCard(
                      label: 'Dispensed',
                      value: '$_dispensedCount',
                      icon: Icons.done_all_outlined,
                      color: AppColors.success,
                      isSelected: _statusFilter == 'dispensed',
                      onTap: () {
                        setState(() => _statusFilter = _statusFilter == 'dispensed' ? null : 'dispensed');
                        _load(search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim());
                      },
                    ),
                    _StatCard(
                      label: 'Cancelled',
                      value: '$_cancelledCount',
                      icon: Icons.cancel_outlined,
                      color: AppColors.error,
                      isSelected: _statusFilter == 'cancelled',
                      onTap: () {
                        setState(() => _statusFilter = _statusFilter == 'cancelled' ? null : 'cancelled');
                        _load(search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim());
                      },
                    ),
                    _StatCard(
                      label: 'Total Meds',
                      value: '$_totalMeds',
                      icon: Icons.medication_outlined,
                      color: Colors.orange,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

          // ── Search + Filters Row ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by patient name or phone...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(
                        const Duration(milliseconds: 400),
                        () => _load(
                            search: v.trim().isEmpty ? null : v.trim()));
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Date range picker button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: _hasDateFilter
                      ? BorderSide(color: AppColors.primary, width: 1.5)
                      : null,
                  foregroundColor:
                      _hasDateFilter ? AppColors.primary : null,
                ),
                onPressed: _pickDateRange,
                icon: const Icon(Icons.date_range_outlined, size: 16),
                label: Text(_hasDateFilter
                    ? '${DateFormat('dd MMM').format(_dateFrom!)} – ${DateFormat('dd MMM').format(_dateTo!)}'
                    : 'Date range'),
              ),
              if (_hasDateFilter) ...
                [
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Clear date filter',
                    onPressed: _clearDateFilter,
                    icon: Icon(Icons.close,
                        size: 16, color: AppColors.error),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
            ],
          ),
          const SizedBox(height: 10),

          // ── Status + Date preset chips ────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Status chips
                for (final entry in [
                  (null, 'All', AppColors.primary),
                  ('active', 'Active', AppColors.primary),
                  ('dispensed', 'Dispensed', AppColors.success),
                  ('cancelled', 'Cancelled', AppColors.error),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(entry.$2),
                      selected: _statusFilter == entry.$1,
                      selectedColor: entry.$3.withValues(alpha: 0.15),
                      checkmarkColor: entry.$3,
                      labelStyle: TextStyle(
                        color: _statusFilter == entry.$1
                            ? entry.$3
                            : AppColors.textSecondary,
                        fontWeight: _statusFilter == entry.$1
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) {
                        setState(() => _statusFilter = entry.$1);
                        _load(
                            search: _searchCtrl.text.trim().isEmpty
                                ? null
                                : _searchCtrl.text.trim());
                      },
                    ),
                  ),
                // Divider
                Container(
                  height: 22,
                  width: 1,
                  margin: const EdgeInsets.only(right: 10),
                  color: AppColors.border,
                ),
                // Date preset chips
                for (final preset in [
                  ('today', 'Today', Icons.today_outlined),
                  ('week', 'This Week', Icons.view_week_outlined),
                  ('month', 'This Month', Icons.calendar_month_outlined),
                  ('year', 'This Year', Icons.calendar_today_outlined),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      avatar: Icon(
                        preset.$3,
                        size: 14,
                        color: _datePreset == preset.$1
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      label: Text(preset.$2),
                      selected: _datePreset == preset.$1,
                      selectedColor: AppColors.primary.withValues(alpha: 0.12),
                      checkmarkColor: AppColors.primary,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: _datePreset == preset.$1
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: _datePreset == preset.$1
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) => _applyDatePreset(preset.$1),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: LoadingWidget())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!,
                                style: TextStyle(color: AppColors.error)),
                            const SizedBox(height: 8),
                            TextButton(
                                onPressed: _load,
                                child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.description_outlined,
                                    size: 56, color: AppColors.border),
                                const SizedBox(height: 12),
                                const Text('No prescriptions yet'),
                                const SizedBox(height: 8),
                                FilledButton.icon(
                                  onPressed: () =>
                                      context.push('/pharmacy-rx/new'),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Create First'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              itemCount: _items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final rx = _items[i];
                                final status = rx['status'] as String? ?? '';
                                final rawItems = (rx['items'] as List?) ?? [];
                                final date = rx['created_at'] != null
                                    ? DateFormat('dd MMM yyyy').format(
                                        DateTime.parse(rx['created_at'] as String))
                                    : '';
                                final phone = rx['patient_phone'] as String? ?? '';
                                final pharmacist = rx['pharmacist_name'] as String? ?? '';
                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                        color: AppColors.border
                                            .withValues(alpha: 0.6)),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => context.push('/pharmacy-rx/${rx['id']}'),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // ── Row 1: name + status + date ──
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundColor: AppColors
                                                    .primary
                                                    .withValues(alpha: 0.12),
                                                child: Text(
                                                  (rx['patient_name']
                                                              as String? ??
                                                          'U')
                                                      .substring(0, 1)
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                      color: AppColors.primary,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      rx['patient_name']
                                                              as String? ??
                                                          'Unknown',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 14),
                                                    ),
                                                    if (phone.isNotEmpty)
                                                      Text(phone,
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color: AppColors
                                                                  .textSecondary)),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  _StatusBadge(status),
                                                  const SizedBox(height: 4),
                                                  Text(date,
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: AppColors
                                                              .textSecondary)),
                                                ],
                                              ),
                                            ],
                                          ),
                                          // ── Medication chips ──
                                          if (rawItems.isNotEmpty) ...
                                            [
                                              const SizedBox(height: 10),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                children: [
                                                  ...rawItems
                                                      .take(4)
                                                      .map((med) => Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical:
                                                                        3),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: AppColors
                                                                  .primary
                                                                  .withValues(
                                                                      alpha:
                                                                          0.07),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          20),
                                                            ),
                                                            child: Text(
                                                              (med as Map<String,
                                                                              dynamic>)[
                                                                          'medication_name'] as String? ??
                                                                      '',
                                                              style: TextStyle(
                                                                  fontSize: 11,
                                                                  color: AppColors
                                                                      .primary),
                                                            ),
                                                          )),
                                                  if (rawItems.length > 4)
                                                    Container(
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 8,
                                                              vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.border
                                                            .withValues(
                                                                alpha: 0.3),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                      ),
                                                      child: Text(
                                                          '+${rawItems.length - 4} more',
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              color: AppColors
                                                                  .textSecondary)),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          const SizedBox(height: 10),
                                          // ── Row 3: pharmacist + actions ──
                                          Row(
                                            children: [
                                              Icon(Icons.person_pin_outlined,
                                                  size: 14,
                                                  color:
                                                      AppColors.textSecondary),
                                              const SizedBox(width: 4),
                                              Text(
                                                  pharmacist.isEmpty
                                                      ? 'Unknown pharmacist'
                                                      : pharmacist,
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors
                                                          .textSecondary)),
                                              const Spacer(),
                                              SizedBox(
                                                height: 28,
                                                child: OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 10),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      textStyle: const TextStyle(
                                                          fontSize: 11)),
                                                  onPressed: () {
                                                    final meds = rawItems
                                                        .map((m) =>
                                                            _RxItem.fromJson(
                                                                m as Map<String,
                                                                    dynamic>))
                                                        .toList();
                                                    _showPrintDialogStatic(
                                                      context: context,
                                                      storeName: ref
                                                              .read(authProvider)
                                                              .valueOrNull
                                                              ?.tenantName ??
                                                          'AdhereMed Pharmacy',
                                                      patientName:
                                                          rx['patient_name']
                                                                  as String? ??
                                                              '',
                                                      patientPhone: phone,
                                                      notes: rx['notes']
                                                              as String? ??
                                                          '',
                                                      status: status,
                                                      pharmacist: pharmacist,
                                                      date: rx['created_at'] !=
                                                              null
                                                          ? DateTime.parse(
                                                              rx['created_at']
                                                                  as String)
                                                          : DateTime.now(),
                                                      items: meds,
                                                    );
                                                  },
                                                  icon: const Icon(
                                                      Icons.print_outlined,
                                                      size: 13),
                                                  label: const Text('Print'),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              SizedBox(
                                                height: 28,
                                                child: FilledButton.icon(
                                                  style: FilledButton.styleFrom(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 10),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      textStyle: const TextStyle(
                                                          fontSize: 11)),
                                                  onPressed: () => context
                                                      .push('/pharmacy-rx/${rx['id']}'),
                                                  icon: const Icon(
                                                      Icons.edit_outlined,
                                                      size: 13),
                                                  label: const Text('Edit'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ─── Form Screen ───────────────────────────────────────────────────────────

class PharmacyPrescriptionFormScreen extends ConsumerStatefulWidget {
  final String? rxId;
  const PharmacyPrescriptionFormScreen({super.key, this.rxId});

  @override
  ConsumerState<PharmacyPrescriptionFormScreen> createState() =>
      _PharmacyPrescriptionFormScreenState();
}

class _PharmacyPrescriptionFormScreenState
    extends ConsumerState<PharmacyPrescriptionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = _PharmacyRxRepository();
  final _inventoryRepo = InventoryRepository();

  final _patientNameCtrl = TextEditingController();
  final _patientPhoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _status = 'active';

  final List<_RxItem> _items = [];
  bool _loading = false;
  bool _initialLoading = false;

  bool get _isEditing => widget.rxId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadExisting();
    } else {
      _items.add(_RxItem());
    }
  }

  @override
  void dispose() {
    _patientNameCtrl.dispose();
    _patientPhoneCtrl.dispose();
    _notesCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _initialLoading = true);
    try {
      final data = await _repo.getDetail(int.parse(widget.rxId!));
      _patientNameCtrl.text = data['patient_name'] ?? '';
      _patientPhoneCtrl.text = data['patient_phone'] ?? '';
      _notesCtrl.text = data['notes'] ?? '';
      _status = data['status'] ?? 'active';
      final rawItems = (data['items'] as List?) ?? [];
      for (final i in rawItems) {
        _items.add(_RxItem.fromJson(i as Map<String, dynamic>));
      }
      if (_items.isEmpty) _items.add(_RxItem());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _initialLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final data = {
        'patient_name': _patientNameCtrl.text.trim(),
        'patient_phone': _patientPhoneCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        'status': _status,
        'items': _items.map((i) => i.toJson()).toList(),
      };
      if (_isEditing) {
        await _repo.update(int.parse(widget.rxId!), data);
      } else {
        await _repo.create(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEditing
                ? 'Prescription updated'
                : 'Prescription saved'),
            backgroundColor: AppColors.success));
        context.go('/pharmacy-rx');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) return const Center(child: LoadingWidget());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page title
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/pharmacy-rx'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isEditing
                        ? 'Edit Prescription'
                        : 'New Pharmacy Prescription',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_isEditing)
                  OutlinedButton.icon(
                    onPressed: () => _showPrintDialog(),
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print'),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Patient Info ────────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(context, Icons.person_outline, 'Patient'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _patientNameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Patient Name *',
                              prefixIcon:
                                  Icon(Icons.person_outline, size: 18),
                            ),
                            validator: (v) =>
                                v == null || v.trim().isEmpty
                                    ? 'Patient name is required'
                                    : null,
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _patientPhoneCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Phone (optional)',
                              prefixIcon:
                                  Icon(Icons.phone_outlined, size: 18),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            value: _status,
                            decoration:
                                const InputDecoration(labelText: 'Status'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'active', child: Text('Active')),
                              DropdownMenuItem(
                                  value: 'dispensed',
                                  child: Text('Dispensed')),
                              DropdownMenuItem(
                                  value: 'cancelled',
                                  child: Text('Cancelled')),
                            ],
                            onChanged: (v) =>
                                setState(() => _status = v ?? 'active'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _notesCtrl,
                            decoration: const InputDecoration(
                                labelText: 'General Notes'),
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Medications ─────────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _sectionTitle(
                            context, Icons.medication_outlined, 'Medications'),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _items.add(_RxItem()));
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Medication'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(_items.length, (i) => _ItemCard(
                          index: i,
                          item: _items[i],
                          inventoryRepo: _inventoryRepo,
                          onRemove: _items.length > 1
                              ? () {
                                  _items[i].dispose();
                                  setState(() => _items.removeAt(i));
                                }
                              : null,
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Save / Print Row ────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _save,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined),
                      label: Text(_loading
                          ? 'Saving...'
                          : _isEditing
                              ? 'Update Prescription'
                              : 'Save Prescription'),
                      style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _showPrintDialog,
                    icon: const Icon(Icons.print_outlined, size: 16),
                    label: const Text('Print'),
                    style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, IconData icon, String label) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      );

  // ─── Print dialog ──────────────────────────────────────────────────────────

  void _showPrintDialog() {
    final storeName = ref.read(authProvider).valueOrNull?.tenantName ?? 'AdhereMed Pharmacy';
    _showPrintDialogStatic(
      context: context,
      storeName: storeName,
      patientName: _patientNameCtrl.text.trim(),
      patientPhone: _patientPhoneCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      status: _status,
      pharmacist: '',
      date: DateTime.now(),
      items: _items,
    );
  }
}

/// Static helper so both list screen and form screen can open the same dialog.
void _showPrintDialogStatic({
  required BuildContext context,
  required String storeName,
  required String patientName,
  required String patientPhone,
  required String notes,
  required String status,
  required String pharmacist,
  required DateTime date,
  required List<_RxItem> items,
}) {
  showDialog(
    context: context,
    builder: (ctx) => _PrintDialog(
      storeName: storeName,
      patientName: patientName,
      patientPhone: patientPhone,
      notes: notes,
      status: status,
      pharmacist: pharmacist,
      date: date,
      items: items,
    ),
  );
}

// ─── Print Dialog (preview + item selection) ──────────────────────────────────

class _PrintDialog extends StatefulWidget {
  final String storeName;
  final String patientName;
  final String patientPhone;
  final String notes;
  final String status;
  final String pharmacist;
  final DateTime date;
  final List<_RxItem> items;

  const _PrintDialog({
    required this.storeName,
    required this.patientName,
    required this.patientPhone,
    required this.notes,
    required this.status,
    required this.pharmacist,
    required this.date,
    required this.items,
  });

  @override
  State<_PrintDialog> createState() => _PrintDialogState();
}

class _PrintDialogState extends State<_PrintDialog> {
  late List<bool> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.filled(widget.items.length, true);
  }

  List<_RxItem> get _selectedItems =>
      [for (int i = 0; i < widget.items.length; i++) if (_selected[i]) widget.items[i]];

  Future<void> _print() async {
    final doc = pw.Document();
    final selectedItems = _selectedItems;
    final dateStr = DateFormat('dd MMM yyyy  HH:mm').format(widget.date);

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity,
          marginAll: 6 * PdfPageFormat.mm),
      build: (pw.Context ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text(widget.storeName,
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 2),
            pw.Center(
                child: pw.Text('PRESCRIPTION',
                    style: const pw.TextStyle(fontSize: 10))),
            pw.Divider(),
            _pdfMeta('Date', dateStr),
            if (widget.patientName.isNotEmpty)
              _pdfMeta('Patient', widget.patientName),
            if (widget.patientPhone.isNotEmpty)
              _pdfMeta('Phone', widget.patientPhone),
            if (widget.pharmacist.isNotEmpty)
              _pdfMeta('Pharmacist', widget.pharmacist),
            _pdfMeta('Status', widget.status.toUpperCase()),
            pw.Divider(),
            // Medication header
            pw.Row(children: [
              pw.Expanded(
                  flex: 4,
                  child: pw.Text('MEDICATION',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9))),
              pw.SizedBox(
                  width: 26,
                  child: pw.Text('QTY',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 9))),
            ]),
            pw.Divider(height: 4),
            ...selectedItems.map((item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 4,
                            child: pw.Text(item.medicationName.text,
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.SizedBox(
                            width: 26,
                            child: pw.Text(
                                item.quantity.text.isEmpty
                                    ? ''
                                    : item.quantity.text,
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(fontSize: 9)),
                          ),
                        ],
                      ),
                      if (item.dosage.text.isNotEmpty ||
                          item.frequency.text.isNotEmpty ||
                          item.duration.text.isNotEmpty)
                        pw.Text(
                          [
                            if (item.dosage.text.isNotEmpty) 'Dose: ${item.dosage.text}',
                            if (item.frequency.text.isNotEmpty) 'Freq: ${item.frequency.text}',
                            if (item.duration.text.isNotEmpty) 'Dur: ${item.duration.text}',
                          ].join('  ·  '),
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      if (item.instructions.text.isNotEmpty)
                        pw.Text('  ${item.instructions.text}',
                            style: pw.TextStyle(
                                fontSize: 8,
                                color: PdfColors.grey700)),
                    ],
                  ),
                )),
            pw.Divider(),
            if (widget.notes.isNotEmpty) ...
              [
                pw.Text('Notes:',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(widget.notes,
                    style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(height: 4),
              ],
            pw.SizedBox(height: 6),
            pw.Center(
                child: pw.Text('--- Powered by AdhereMed ---',
                    style: pw.TextStyle(
                        fontSize: 7, color: PdfColors.grey))),
          ],
        );
      },
    ));

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save());
  }

  pw.Widget _pdfMeta(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
                width: 60,
                child: pw.Text(label,
                    style: const pw.TextStyle(fontSize: 8))),
            pw.Expanded(
                child: pw.Text(value,
                    style: const pw.TextStyle(fontSize: 8))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final selectedItems = _selectedItems;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  Icon(Icons.print_outlined,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Print Prescription',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Medication checkboxes
                    Text('Select medications to print:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    ...List.generate(widget.items.length, (i) {
                      final item = widget.items[i];
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: _selected[i],
                        onChanged: (v) =>
                            setState(() => _selected[i] = v ?? false),
                        title: Text(
                          item.medicationName.text.isEmpty
                              ? 'Medication ${i + 1}'
                              : item.medicationName.text,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: Text(
                          [
                            if (item.dosage.text.isNotEmpty) 'Dose: ${item.dosage.text}',
                            if (item.frequency.text.isNotEmpty) 'Freq: ${item.frequency.text}',
                            if (item.duration.text.isNotEmpty) 'Dur: ${item.duration.text}',
                            if (item.quantity.text.isNotEmpty) 'Qty: ${item.quantity.text}',
                          ].join('  ·  '),
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                        controlAffinity:
                            ListTileControlAffinity.leading,
                      );
                    }),
                    const SizedBox(height: 10),
                    // Select all / none
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setState(() =>
                              _selected =
                                  List.filled(widget.items.length, true)),
                          child: const Text('Select all'),
                        ),
                        TextButton(
                          onPressed: () => setState(() =>
                              _selected =
                                  List.filled(widget.items.length, false)),
                          child: const Text('Deselect all'),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    // Thermal preview
                    _RxThermalWidget(
                      storeName: widget.storeName,
                      patientName: widget.patientName,
                      patientPhone: widget.patientPhone,
                      notes: widget.notes,
                      status: widget.status,
                      pharmacist: widget.pharmacist,
                      date: widget.date,
                      items: selectedItems,
                    ),
                  ],
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: selectedItems.isEmpty ? null : _print,
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: Text(selectedItems.isEmpty
                          ? 'Select items'
                          : 'Print (${selectedItems.length})'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Thermal Preview Widget ────────────────────────────────────────────────────

class _RxThermalWidget extends StatelessWidget {
  final String storeName;
  final String patientName;
  final String patientPhone;
  final String notes;
  final String status;
  final String pharmacist;
  final DateTime date;
  final List<_RxItem> items;

  const _RxThermalWidget({
    required this.storeName,
    required this.patientName,
    required this.patientPhone,
    required this.notes,
    required this.status,
    required this.pharmacist,
    required this.date,
    required this.items,
  });

  static const _mono = TextStyle(
      fontFamily: 'monospace', fontSize: 12, color: Colors.black);
  static const _monoBold = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: Colors.black);
  static const _monoLg = TextStyle(
      fontFamily: 'monospace',
      fontSize: 15,
      fontWeight: FontWeight.bold,
      color: Colors.black);
  static const _monoSm = TextStyle(
      fontFamily: 'monospace', fontSize: 11, color: Colors.black54);

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy  HH:mm').format(date);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
              child: Text(storeName.toUpperCase(),
                  style: _monoLg, textAlign: TextAlign.center)),
          const SizedBox(height: 2),
          Center(
              child: Text('** PRESCRIPTION **',
                  style: _monoSm, textAlign: TextAlign.center)),
          const SizedBox(height: 6),
          _RxDashes(),
          _metaRow('Date:', dateStr),
          if (patientName.isNotEmpty) _metaRow('Patient:', patientName),
          if (patientPhone.isNotEmpty) _metaRow('Phone:', patientPhone),
          if (pharmacist.isNotEmpty) _metaRow('By:', pharmacist),
          _metaRow('Status:', status.toUpperCase()),
          _RxDashes(),
          Row(children: [
            Expanded(child: Text('MEDICATION', style: _monoBold)),
            SizedBox(
                width: 36,
                child: Text('QTY', style: _monoBold, textAlign: TextAlign.right)),
          ]),
          _RxDashes(dashed: false),
          if (items.isEmpty)
            Center(
                child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('(no medications selected)', style: _monoSm),
            ))
          else
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Text(item.medicationName.text,
                                  style: _monoBold,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis)),
                          SizedBox(
                              width: 36,
                              child: Text(
                                  item.quantity.text.isEmpty
                                      ? ''
                                      : item.quantity.text,
                                  style: _mono,
                                  textAlign: TextAlign.right)),
                        ],
                      ),
                      if (item.dosage.text.isNotEmpty ||
                          item.frequency.text.isNotEmpty ||
                          item.duration.text.isNotEmpty)
                        Text(
                          [
                            if (item.dosage.text.isNotEmpty) 'Dose: ${item.dosage.text}',
                            if (item.frequency.text.isNotEmpty) 'Freq: ${item.frequency.text}',
                            if (item.duration.text.isNotEmpty) 'Dur: ${item.duration.text}',
                          ].join('  ·  '),
                          style: _monoSm,
                        ),
                      if (item.instructions.text.isNotEmpty)
                        Text('  ${item.instructions.text}',
                            style: _monoSm.copyWith(color: Colors.black38)),
                    ],
                  ),
                )),
          _RxDashes(),
          if (notes.isNotEmpty) ...
            [
              Text('Notes:', style: _monoBold),
              Text(notes, style: _mono),
              const SizedBox(height: 4),
            ],
          const SizedBox(height: 6),
          Center(
              child: Text('--- Powered by AdhereMed ---',
                  style: _monoSm.copyWith(fontSize: 10),
                  textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 60, child: Text(label, style: _monoSm)),
            Expanded(child: Text(value, style: _mono)),
          ],
        ),
      );
}

class _RxDashes extends StatelessWidget {
  final bool dashed;
  const _RxDashes({this.dashed = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: dashed
          ? const Text('- - - - - - - - - - - - - - - - - - - - - - - -',
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10,
                  color: Colors.black26),
              maxLines: 1,
              overflow: TextOverflow.clip)
          : const Divider(height: 4, color: Colors.black26),
    );
  }
}

// ─── Single Medication Item Card ────────────────────────────────────────────

class _ItemCard extends StatefulWidget {
  final int index;
  final _RxItem item;
  final InventoryRepository inventoryRepo;
  final VoidCallback? onRemove;

  const _ItemCard({
    required this.index,
    required this.item,
    required this.inventoryRepo,
    this.onRemove,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  List<MedicationStock> _suggestions = [];
  bool _searching = false;
  Timer? _debounce;
  final _focusNode = FocusNode();
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        // Delay so any ListTile onTap fires before the dropdown is hidden.
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _showDropdown = false);
        });
      }
    });
    widget.item.frequency.addListener(_calcQty);
    widget.item.duration.addListener(_calcQty);
    widget.item.dosage.addListener(_calcQty);
  }

  @override
  void dispose() {
    widget.item.frequency.removeListener(_calcQty);
    widget.item.duration.removeListener(_calcQty);
    widget.item.dosage.removeListener(_calcQty);
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Auto-quantity calculation ──────────────────────────────────────────

  void _calcQty() {
    final freq = _parseFrequency(widget.item.frequency.text);
    final dur = _parseDuration(widget.item.duration.text);
    if (freq == null || dur == null) return;
    final units = _parseDosageUnits(widget.item.dosage.text) ?? 1;
    final qty = freq * dur * units;
    if (qty > 0) widget.item.quantity.text = '$qty';
  }

  /// Returns doses per day from common frequency strings.
  int? _parseFrequency(String text) {
    final t = text.toLowerCase().trim();
    if (t.isEmpty) return null;
    // Abbreviations
    if (RegExp(r'^(od|once\s*daily|once\s*a\s*day|1x|1\s*time)').hasMatch(t)) return 1;
    if (RegExp(r'^(bd|bid|twice\s*daily|twice\s*a\s*day|2x)').hasMatch(t)) return 2;
    if (RegExp(r'^(tds|tid|trice|thrice|three\s*times)').hasMatch(t)) return 3;
    if (RegExp(r'^(qds|qid|four\s*times)').hasMatch(t)) return 4;
    // "N times daily / per day / /day"
    final m = RegExp(r'(\d+)\s*(?:times?|x)\s*(?:daily|a\s*day|per\s*day|/day)').firstMatch(t);
    if (m != null) return int.tryParse(m.group(1)!);
    // "every N hours"
    final eh = RegExp(r'every\s*(\d+)\s*hours?').firstMatch(t);
    if (eh != null) {
      final h = int.tryParse(eh.group(1)!);
      if (h != null && h > 0) return (24 / h).round();
    }
    // bare number
    final bare = RegExp(r'^(\d+)$').firstMatch(t);
    if (bare != null) return int.tryParse(bare.group(1)!);
    return null;
  }

  /// Returns duration in days from strings like "7 days", "2 weeks", "1 month".
  int? _parseDuration(String text) {
    final t = text.toLowerCase().trim();
    if (t.isEmpty) return null;
    final days = RegExp(r'(\d+)\s*days?').firstMatch(t);
    if (days != null) return int.tryParse(days.group(1)!);
    final weeks = RegExp(r'(\d+)\s*weeks?').firstMatch(t);
    if (weeks != null) return (int.tryParse(weeks.group(1)!) ?? 0) * 7;
    final months = RegExp(r'(\d+)\s*months?').firstMatch(t);
    if (months != null) return (int.tryParse(months.group(1)!) ?? 0) * 30;
    // bare number → assume days
    final bare = RegExp(r'^(\d+)$').firstMatch(t);
    if (bare != null) return int.tryParse(bare.group(1)!);
    return null;
  }

  /// Returns tablet/unit count per dose from dosage strings.
  int? _parseDosageUnits(String text) {
    final t = text.toLowerCase().trim();
    if (t.isEmpty) return null;
    final unit = RegExp(
            r'(\d+)\s*(?:tablets?|caps?|capsules?|pills?|units?|drops?|puffs?|sachets?)')
        .firstMatch(t);
    if (unit != null) return int.tryParse(unit.group(1)!);
    // just a leading number (e.g. "2" or "1.5")
    final num = RegExp(r'^(\d+)').firstMatch(t);
    if (num != null) return int.tryParse(num.group(1)!);
    return null;
  }

  Future<void> _search(String q) async {
    if (q.length < 2) {
      setState(() {
        _suggestions = [];
        _showDropdown = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final result = await widget.inventoryRepo.getStocks(search: q);
      if (mounted) {
        setState(() {
          _suggestions = result.results;
          _showDropdown = result.results.isNotEmpty;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _select(MedicationStock stock) {
    widget.item.medicationName.text = stock.medicationName;
    widget.item.stockId = stock.id;
    setState(() {
      _suggestions = [];
      _showDropdown = false;
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.background,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card header
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Medication ${widget.index + 1}',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
                const Spacer(),
                if (widget.onRemove != null)
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 18, color: AppColors.error),
                    onPressed: widget.onRemove,
                    tooltip: 'Remove',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Medication name with search dropdown
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: widget.item.medicationName,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    labelText: 'Medication Name *',
                    hintText: 'Type to search inventory or enter manually',
                    prefixIcon:
                        const Icon(Icons.medication_outlined, size: 18),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)))
                        : widget.item.stockId != null
                            ? Icon(Icons.check_circle,
                                color: AppColors.success, size: 18)
                            : const Icon(Icons.edit_outlined, size: 18),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                  onChanged: (v) {
                    // Clear stock link if user edits manually
                    if (widget.item.stockId != null) {
                      setState(() => widget.item.stockId = null);
                    }
                    _debounce?.cancel();
                    _debounce = Timer(
                        const Duration(milliseconds: 350), () => _search(v));
                  },
                ),
                if (_showDropdown && _suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (ctx, i) {
                        final s = _suggestions[i];
                        final qty = s.totalQuantity ?? 0;
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.medication_outlined,
                              size: 18, color: AppColors.primary),
                          title: Text(s.medicationName,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                            'Stock: $qty  •  ${s.categoryName ?? ''}',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                          ),
                          trailing: Text(
                            'KSh ${s.sellingPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600),
                          ),
                          onTap: () => _select(s),
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Dosage · Frequency · Duration · Qty ──────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.12)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: widget.item.dosage,
                          decoration: InputDecoration(
                            labelText: 'Dosage',
                            hintText: '500mg',
                            isDense: true,
                            prefixIcon: Icon(
                                Icons.medication_liquid_outlined,
                                size: 16,
                                color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          controller: widget.item.frequency,
                          decoration: InputDecoration(
                            labelText: 'Frequency',
                            hintText: '3x daily / BD / TDS',
                            isDense: true,
                            prefixIcon: Icon(Icons.repeat_outlined,
                                size: 16, color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: widget.item.duration,
                          decoration: InputDecoration(
                            labelText: 'Duration',
                            hintText: '7 days',
                            isDense: true,
                            prefixIcon: Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 88,
                        child: TextFormField(
                          controller: widget.item.quantity,
                          decoration: InputDecoration(
                            labelText: 'Qty',
                            isDense: true,
                            prefixIcon: Icon(Icons.numbers_outlined,
                                size: 16, color: AppColors.primary),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: widget.item.instructions,
                    decoration: InputDecoration(
                      labelText: 'Instructions',
                      hintText:
                          'e.g. Take after meals, avoid alcohol…',
                      isDense: true,
                      prefixIcon: Icon(Icons.info_outline,
                          size: 16, color: AppColors.primary),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Card ─────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 120,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.2),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isSelected ? 0.22 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color,
                          height: 1.1)),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? color : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status Badge ──────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'dispensed' => (AppColors.success, 'Dispensed'),
      'cancelled' => (AppColors.error, 'Cancelled'),
      _ => (AppColors.primary, 'Active'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold)),
    );
  }
}
