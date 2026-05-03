import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/stat_card.dart';
import '../models/prescription_model.dart';
import '../repository/prescription_repository.dart';

class PrescriptionListScreen extends ConsumerStatefulWidget {
  const PrescriptionListScreen({super.key});

  @override
  ConsumerState<PrescriptionListScreen> createState() =>
      _PrescriptionListScreenState();
}

class _PrescriptionListScreenState
    extends ConsumerState<PrescriptionListScreen> {
  final _repo = PrescriptionRepository();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  PaginatedResponse<Prescription>? _data;
  bool _loading = true;
  String? _error;
  int _page = 1;
  String _search = '';
  String _statusFilter = 'all';
  Map<String, int> _statusCounts = {};

  static const _statuses = [
    'all',
    'active',
    'sent_to_exchange',
    'dispensed',
    'cancelled',
    'expired',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadStats();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      const statuses = ['active', 'sent_to_exchange', 'dispensed', 'cancelled'];
      final results = await Future.wait(
        statuses.map((s) => _repo.getList(status: s, page: 1)),
      );
      if (mounted) {
        setState(() {
          _statusCounts = {
            for (int i = 0; i < statuses.length; i++)
              statuses[i]: results[i].count,
          };
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repo.getList(
        page: _page,
        search: _search.isEmpty ? null : _search,
        status: _statusFilter == 'all' ? null : _statusFilter,
      );
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _sendToExchange(int id) async {
    try {
      await _repo.sendToExchange(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Prescription sent to exchange'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _loadData();
        _loadStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  int get _totalPages => (_data != null && _data!.count > 0)
      ? ((_data!.count + 19) ~/ 20)
      : 1;

  int get _rangeStart => (_page - 1) * 20 + 1;
  int get _rangeEnd {
    final end = _page * 20;
    return _data != null && end > _data!.count ? _data!.count : end;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'sent_to_exchange':
      case 'pending':
        return AppColors.warning;
      case 'cancelled':
      case 'expired':
        return AppColors.error;
      case 'dispensed':
      case 'completed':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'all':
        return 'All';
      case 'sent_to_exchange':
        return 'Exchanged';
      default:
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return '—';
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(iso));
    } catch (_) {
      return iso.split('T').first;
    }
  }

  String _medicationSummary(List<PrescriptionItem> items) {
    if (items.isEmpty) return '—';
    final names = items
        .map((e) => (e.isCustom && e.customMedicationName != null)
            ? e.customMedicationName!
            : e.medicationName)
        .take(2)
        .join(', ');
    return items.length > 2 ? '$names +${items.length - 2}' : names;
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _statusCounts.isEmpty
        ? (_data?.count ?? 0)
        : _statusCounts.values.fold(0, (a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // â”€â”€ Header â”€â”€
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.primary.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(Icons.receipt_long_rounded,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prescriptions',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Manage and track patient prescriptions',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.push('/prescriptions/new'),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('New Prescription'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // â”€â”€ Stats Row â”€â”€
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.receipt_long_rounded,
                  title: 'Total Rx',
                  value: '$totalCount',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.check_circle_rounded,
                  title: 'Active',
                  value: '${_statusCounts['active'] ?? 0}',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Sent to Exchange',
                  value: '${_statusCounts['sent_to_exchange'] ?? 0}',
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.local_pharmacy_rounded,
                  title: 'Dispensed',
                  value: '${_statusCounts['dispensed'] ?? 0}',
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // â”€â”€ Search & Filters Bar â”€â”€
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                // Search field
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by patient name...',
                      hintStyle: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13.5),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: AppColors.textSecondary, size: 20),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close_rounded,
                                  size: 18, color: AppColors.textSecondary),
                              onPressed: () {
                                _searchCtrl.clear();
                                _search = '';
                                _page = 1;
                                _loadData();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      _debounce?.cancel();
                      _debounce =
                          Timer(const Duration(milliseconds: 400), () {
                        _search = v;
                        _page = 1;
                        _loadData();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Container(height: 32, width: 1, color: AppColors.border),
                const SizedBox(width: 12),
                // Filter chips
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _statuses.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, i) {
                        final s = _statuses[i];
                        final selected = _statusFilter == s;
                        final color =
                            s == 'all' ? AppColors.primary : _statusColor(s);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _statusFilter = s;
                              _page = 1;
                            });
                            _loadData();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected ? color : AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color:
                                    selected ? color : AppColors.border,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _statusLabel(s),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary,
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
          ),
          const SizedBox(height: 16),

          // â”€â”€ Table â”€â”€
          Expanded(
            child: _loading
                ? const LoadingWidget()
                : _error != null
                    ? app_error.AppErrorWidget(
                        message: _error!, onRetry: _loadData)
                    : _data == null || _data!.results.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.description_outlined,
                            title: 'No prescriptions found',
                            subtitle: _search.isNotEmpty
                                ? 'Try a different search term'
                                : 'Create your first prescription to get started',
                            actionLabel:
                                _search.isEmpty ? 'New Prescription' : null,
                            onAction: _search.isEmpty
                                ? () => context.push('/prescriptions/new')
                                : null,
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                // â”€â”€ Table header â”€â”€
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(14)),
                                    border: Border(
                                      bottom:
                                          BorderSide(color: AppColors.border),
                                    ),
                                  ),
                                  child: Row(
                                    children: const [
                                      SizedBox(
                                          width: 64,
                                          child: _HeaderCell('Rx #')),
                                      Expanded(
                                          flex: 3,
                                          child: _HeaderCell('Patient')),
                                      Expanded(
                                          flex: 3,
                                          child: _HeaderCell('Doctor')),
                                      Expanded(
                                          flex: 4,
                                          child:
                                              _HeaderCell('Medications')),
                                      Expanded(
                                          flex: 2,
                                          child: _HeaderCell('Status')),
                                      Expanded(
                                          flex: 2,
                                          child: _HeaderCell('Date')),
                                      SizedBox(
                                          width: 130,
                                          child: _HeaderCell('Actions')),
                                    ],
                                  ),
                                ),
                                // â”€â”€ Table rows â”€â”€
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _data!.results.length,
                                    itemBuilder: (context, index) {
                                      final p = _data!.results[index];
                                      return _PrescriptionRow(
                                        prescription: p,
                                        isLast: index ==
                                            _data!.results.length - 1,
                                        statusColor:
                                            _statusColor(p.status),
                                        statusLabel:
                                            _statusLabel(p.status),
                                        formattedDate:
                                            _formatDate(p.createdAt),
                                        medicationSummary:
                                            _medicationSummary(p.items),
                                        onView: () => context.push(
                                            '/prescriptions/${p.id}'),
                                        onEdit: () => context.push(
                                            '/prescriptions/${p.id}/edit'),
                                        onSendToExchange:
                                            p.status == 'active'
                                                ? () =>
                                                    _sendToExchange(p.id)
                                                : null,
                                        onDelete: () =>
                                            _deletePrescription(p),
                                      );
                                    },
                                  ),
                                ),
                                // â”€â”€ Pagination Bar â”€â”€
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius:
                                        const BorderRadius.vertical(
                                            bottom: Radius.circular(14)),
                                    border: Border(
                                      top: BorderSide(
                                          color: AppColors.divider),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors
                                                  .textSecondary),
                                          children: [
                                            const TextSpan(
                                                text: 'Showing '),
                                            TextSpan(
                                              text:
                                                  '$_rangeStart\u2013$_rangeEnd',
                                              style: TextStyle(
                                                fontWeight:
                                                    FontWeight.w600,
                                                color: AppColors
                                                    .textPrimary,
                                              ),
                                            ),
                                            TextSpan(
                                                text:
                                                    ' of ${_data!.count} prescriptions'),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: AppColors.border),
                                        ),
                                        child: Row(
                                          children: [
                                            _PaginationBtn(
                                              icon: Icons
                                                  .chevron_left_rounded,
                                              enabled:
                                                  _data!.previous != null,
                                              onTap: () {
                                                _page--;
                                                _loadData();
                                              },
                                              isLeft: true,
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 16,
                                                      vertical: 8),
                                              decoration: BoxDecoration(
                                                border: Border.symmetric(
                                                  vertical: BorderSide(
                                                      color: AppColors
                                                          .border),
                                                ),
                                              ),
                                              child: Text(
                                                'Page $_page of $_totalPages',
                                                style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            _PaginationBtn(
                                              icon: Icons
                                                  .chevron_right_rounded,
                                              enabled:
                                                  _data!.next != null,
                                              onTap: () {
                                                _page++;
                                                _loadData();
                                              },
                                              isLeft: false,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePrescription(Prescription p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Delete Prescription'),
          ],
        ),
        content: Text('Are you sure you want to delete prescription #${p.id}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await _repo.delete(p.id);
        _loadData();
        _loadStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Prescription deleted'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }
}

// ââ Prescription Row ââ
class _PrescriptionRow extends StatefulWidget {
  final Prescription prescription;
  final bool isLast;
  final Color statusColor;
  final String statusLabel;
  final String formattedDate;
  final String medicationSummary;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback? onSendToExchange;
  final VoidCallback onDelete;

  const _PrescriptionRow({
    required this.prescription,
    required this.isLast,
    required this.statusColor,
    required this.statusLabel,
    required this.formattedDate,
    required this.medicationSummary,
    required this.onView,
    required this.onEdit,
    this.onSendToExchange,
    required this.onDelete,
  });

  @override
  State<_PrescriptionRow> createState() => _PrescriptionRowState();
}

class _PrescriptionRowState extends State<_PrescriptionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.prescription;
    final sc = widget.statusColor;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _hovered
              ? AppColors.primary.withValues(alpha: 0.04)
              : Colors.transparent,
          border: widget.isLast
              ? null
              : Border(
                  bottom: BorderSide(color: AppColors.divider),
                ),
        ),
        child: InkWell(
          onTap: widget.onView,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(
              children: [
                // Rx #
                SizedBox(
                  width: 64,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#${p.id}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                // Patient
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      _Avatar(name: p.patientName, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          p.patientName ?? 'Unknown',
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 13.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Doctor
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      _Avatar(
                          name: p.doctorName, color: AppColors.secondary),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          p.doctorName ?? 'Unknown',
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 13.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Medications
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Icon(Icons.medication_rounded,
                          size: 13,
                          color:
                              AppColors.textSecondary.withValues(alpha: 0.6)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          widget.medicationSummary,
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status
                Expanded(
                  flex: 2,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: sc,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            widget.statusLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sc,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Date
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 12,
                          color: AppColors.textSecondary
                              .withValues(alpha: 0.5)),
                      const SizedBox(width: 5),
                      Text(
                        widget.formattedDate,
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Actions
                SizedBox(
                  width: 130,
                  child: Row(
                    children: [
                      _ActionBtn(
                        icon: Icons.visibility_outlined,
                        color: AppColors.primary,
                        tooltip: 'View',
                        onTap: widget.onView,
                      ),
                      const SizedBox(width: 4),
                      _ActionBtn(
                        icon: Icons.edit_outlined,
                        color: AppColors.secondary,
                        tooltip: 'Edit',
                        onTap: widget.onEdit,
                      ),
                      if (widget.onSendToExchange != null) ...[
                        const SizedBox(width: 4),
                        _ActionBtn(
                          icon: Icons.send_rounded,
                          color: AppColors.warning,
                          tooltip: 'Send to Exchange',
                          onTap: widget.onSendToExchange!,
                        ),
                      ],
                      const SizedBox(width: 4),
                      _ActionBtn(
                        icon: Icons.delete_outline,
                        color: AppColors.error,
                        tooltip: 'Delete',
                        onTap: widget.onDelete,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ââ Avatar ââ
class _Avatar extends StatelessWidget {
  final String? name;
  final Color color;

  const _Avatar({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    final initial =
        (name != null && name!.isNotEmpty) ? name![0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 15,
      backgroundColor: color.withValues(alpha: 0.1),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ââ Header Cell ââ
class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 11,
        color: AppColors.textSecondary,
        letterSpacing: 0.6,
      ),
    );
  }
}

// â”€â”€ Action Button â”€â”€
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// â”€â”€ Pagination Button â”€â”€
class _PaginationBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool isLeft;

  const _PaginationBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.horizontal(
        left: isLeft ? const Radius.circular(8) : Radius.zero,
        right: isLeft ? Radius.zero : const Radius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.textPrimary : AppColors.border,
        ),
      ),
    );
  }
}
