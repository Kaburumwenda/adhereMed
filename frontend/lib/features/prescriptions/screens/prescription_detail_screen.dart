import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/error_widget.dart' as app_error;
import '../models/prescription_model.dart';
import '../repository/prescription_repository.dart';
import '../../pharmacy_store/models/pharmacy_store_models.dart';
import '../../pharmacy_store/repository/pharmacy_store_repository.dart';

class PrescriptionDetailScreen extends ConsumerStatefulWidget {
  final String prescriptionId;

  const PrescriptionDetailScreen({super.key, required this.prescriptionId});

  @override
  ConsumerState<PrescriptionDetailScreen> createState() =>
      _PrescriptionDetailScreenState();
}

class _PrescriptionDetailScreenState
    extends ConsumerState<PrescriptionDetailScreen> {
  final _repo = PrescriptionRepository();
  Prescription? _prescription;
  bool _loading = true;
  String? _error;
  bool _sendingToExchange = false;

  void _getQuoteFromPharmacy() {
    final p = _prescription;
    if (p == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PharmacyQuoteSheet(items: p.items),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result =
          await _repo.getDetail(int.parse(widget.prescriptionId));
      setState(() {
        _prescription = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _sendToExchange() async {
    setState(() => _sendingToExchange = true);
    try {
      await _repo.sendToExchange(int.parse(widget.prescriptionId));
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
    if (mounted) setState(() => _sendingToExchange = false);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'pending':
      case 'processing':
        return AppColors.warning;
      case 'cancelled':
        return AppColors.error;
      case 'completed':
      case 'dispensed':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.check_circle_rounded;
      case 'pending':
      case 'processing':
        return Icons.schedule_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'completed':
      case 'dispensed':
        return Icons.verified_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();
    if (_error != null) {
      return app_error.AppErrorWidget(message: _error!, onRetry: _loadData);
    }
    final p = _prescription!;
    final sColor = _statusColor(p.status);
    final date = p.createdAt?.split('T').first ?? '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Banner ──
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => context.pop(),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prescription #${p.id}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  size: 13),
                              const SizedBox(width: 4),
                              Text(
                                date,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Status pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_statusIcon(p.status),
                              size: 15, color: sColor),
                          const SizedBox(width: 5),
                          Text(
                            p.status[0].toUpperCase() +
                                p.status.substring(1),
                            style: TextStyle(
                              color: sColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (p.status == 'active') ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          _sendingToExchange ? null : _sendToExchange,
                      icon: _sendingToExchange
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_sendingToExchange
                          ? 'Sending...'
                          : 'Send to Exchange'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _getQuoteFromPharmacy,
                      icon: const Icon(Icons.local_pharmacy_outlined, size: 18),
                      label: const Text('Get Quote from Pharmacy'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.7)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
                if (p.status == 'sent_to_exchange' ||
                    p.status == 'completed' ||
                    p.status == 'dispensed') ...[
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _getQuoteFromPharmacy,
                      icon: const Icon(Icons.local_pharmacy_outlined, size: 18),
                      label: const Text('Get Quote from Pharmacy'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.7)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Patient & Doctor Cards ──
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  icon: Icons.person_rounded,
                  iconBg: AppColors.primary.withValues(alpha: 0.1),
                  iconColor: AppColors.primary,
                  label: 'Patient',
                  value: p.patientName ?? 'Unknown Patient',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _InfoTile(
                  icon: Icons.medical_services_rounded,
                  iconBg: AppColors.secondary.withValues(alpha: 0.1),
                  iconColor: AppColors.secondary,
                  label: 'Prescribing Doctor',
                  value: p.doctorName ?? 'Unknown Doctor',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Notes Card ──
          if ((p.notes ?? '').isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sticky_note_2_rounded,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Clinical Notes',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.warning)),
                        const SizedBox(height: 4),
                        Text(p.notes!,
                            style: TextStyle(
                                fontSize: 13.5,
                                color: AppColors.textPrimary,
                                height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if ((p.notes ?? '').isNotEmpty) const SizedBox(height: 24),

          // ── Prescribed Medications ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.medication_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Text('Prescribed Medications',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${p.items.length}',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (p.items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.medication_outlined,
                      size: 40, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text('No medications prescribed',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            )
          else
            ...p.items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return _MedicationCard(index: idx, item: item);
            }),
        ],
      ),
    );
  }
}

// ── Info Tile Widget ──
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Medication Card Widget ──
class _MedicationCard extends StatelessWidget {
  final int index;
  final PrescriptionItem item;

  const _MedicationCard({required this.index, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${index + 1}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.primary)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.medicationName,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.5,
                              color: AppColors.textPrimary)),
                      if (item.isCustom)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Custom Entry',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.warning)),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Qty: ${item.quantity}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: AppColors.secondary)),
                ),
              ],
            ),
          ),
          // Card body — details grid
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: _DetailChip(
                    icon: Icons.science_rounded,
                    label: 'Dosage',
                    value: item.dosage,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DetailChip(
                    icon: Icons.repeat_rounded,
                    label: 'Frequency',
                    value: item.frequency,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DetailChip(
                    icon: Icons.timer_rounded,
                    label: 'Duration',
                    value: item.duration,
                  ),
                ),
              ],
            ),
          ),
          // Instructions
          if ((item.instructions ?? '').isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.instructions!,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Detail Chip Widget ──
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value.isEmpty ? '-' : value,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ===========================================================================
// Get Quote from Pharmacy – Bottom Sheet
// ===========================================================================

class _PharmacyQuoteSheet extends StatefulWidget {
  final List<PrescriptionItem> items;
  const _PharmacyQuoteSheet({required this.items});

  @override
  State<_PharmacyQuoteSheet> createState() => _PharmacyQuoteSheetState();
}

class _PharmacyQuoteSheetState extends State<_PharmacyQuoteSheet> {
  final _storeRepo = PharmacyStoreRepository();

  // Stage: 'select_pharmacy' | 'checking' | 'results'
  String _stage = 'select_pharmacy';

  List<PharmacyInfo> _pharmacies = [];
  bool _loadingPharmacies = true;
  String? _pharmaciesError;

  PharmacyInfo? _selectedPharmacy;
  // Map<medicationId (as string) OR name, PharmacyProduct?>
  // key = lowercased medication name, value = matched product or null
  Map<String, PharmacyProduct?> _availability = {};
  String? _checkError;

  @override
  void initState() {
    super.initState();
    _loadPharmacies();
  }

  Future<void> _loadPharmacies() async {
    try {
      final list = await _storeRepo.getPharmacies();
      if (mounted) {
        setState(() {
          _pharmacies = list;
          _loadingPharmacies = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pharmaciesError = e.toString();
          _loadingPharmacies = false;
        });
      }
    }
  }

  Future<void> _checkAvailability(PharmacyInfo pharmacy) async {
    setState(() {
      _selectedPharmacy = pharmacy;
      _stage = 'checking';
      _checkError = null;
      _availability = {};
    });
    try {
      final pharmacyId = pharmacy.id.toString();
      final availability = <String, PharmacyProduct?>{};

      // Search each medication by name individually so pagination is not an issue
      await Future.wait(widget.items.map((item) async {
        final searchName = item.medicationName.trim();
        try {
          final result = await _storeRepo.getProducts(
            pharmacyId,
            page: 1,
            search: searchName,
          );
          // Find the best match: exact name match (case-insensitive) first,
          // then any partial match returned by the server search.
          PharmacyProduct? match;
          final nameLower = searchName.toLowerCase();
          for (final p in result.products) {
            if (p.medicationName.toLowerCase().trim() == nameLower) {
              match = p;
              break;
            }
          }
          // Fallback: take first result if server returned anything
          match ??= result.products.isNotEmpty ? result.products.first : null;
          availability[item.medicationName] = match;
        } catch (_) {
          availability[item.medicationName] = null;
        }
      }));

      if (mounted) {
        setState(() {
          _availability = availability;
          _stage = 'results';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkError = e.toString();
          _stage = 'results';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetRadius = const BorderRadius.vertical(top: Radius.circular(24));
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: sheetRadius,
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.local_pharmacy_outlined,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Get Quote from Pharmacy',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          if (_selectedPharmacy != null && _stage == 'results')
                            Text(_selectedPharmacy!.name,
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                        ],
                      ),
                    ),
                    if (_stage == 'results')
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _stage = 'select_pharmacy';
                          _selectedPharmacy = null;
                          _availability = {};
                        }),
                        icon: const Icon(Icons.arrow_back, size: 14),
                        label: const Text('Change',
                            style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Body
              Expanded(
                child: _buildBody(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ScrollController sc) {
    switch (_stage) {
      case 'select_pharmacy':
        return _buildPharmacySelector(sc);
      case 'checking':
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoadingWidget(),
              SizedBox(height: 16),
              Text('Checking pharmacy inventory…'),
            ],
          ),
        );
      case 'results':
        return _buildResults(sc);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPharmacySelector(ScrollController sc) {
    if (_loadingPharmacies) {
      return const Center(child: LoadingWidget());
    }
    if (_pharmaciesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: AppColors.error, size: 40),
              const SizedBox(height: 12),
              Text('Failed to load pharmacies',
                  style: TextStyle(color: AppColors.error)),
              const SizedBox(height: 8),
              FilledButton(
                  onPressed: () {
                    setState(() {
                      _loadingPharmacies = true;
                      _pharmaciesError = null;
                    });
                    _loadPharmacies();
                  },
                  child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_pharmacies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_pharmacy_outlined,
                  color: AppColors.textSecondary, size: 40),
              const SizedBox(height: 12),
              Text('No pharmacies available',
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      controller: sc,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _pharmacies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final ph = _pharmacies[i];
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.border),
          ),
          tileColor: AppColors.surface,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.local_pharmacy,
                color: AppColors.primary, size: 20),
          ),
          title: Text(ph.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: ph.city.isNotEmpty
              ? Text(ph.city,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12))
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ph.deliveryRadiusKm > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Delivery',
                      style: TextStyle(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
          onTap: () => _checkAvailability(ph),
        );
      },
    );
  }

  Widget _buildResults(ScrollController sc) {
    final available =
        _availability.values.where((v) => v != null).length;
    final total = widget.items.length;
    final notAvailable = total - available;

    return ListView(
      controller: sc,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Summary banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SummaryChip(
                  label: 'Available',
                  count: available,
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryChip(
                  label: 'Not Found',
                  count: notAvailable,
                  color: AppColors.error,
                  icon: Icons.cancel_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryChip(
                  label: 'Total',
                  count: total,
                  color: AppColors.primary,
                  icon: Icons.medication_outlined,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _LegendDot(color: AppColors.error, label: 'Strikethrough = present in pharmacy inventory'),
            ],
          ),
        ),
        if (_checkError != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Could not fully check inventory: $_checkError',
                        style: TextStyle(
                            color: AppColors.error, fontSize: 12))),
              ],
            ),
          ),
        if (_checkError != null) const SizedBox(height: 12),
        // Medication rows
        ...widget.items.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final match = _availability[item.medicationName];
          final isPresent = match != null;
          return _QuoteMedicationRow(
            index: idx,
            item: item,
            product: match,
            isPresent: isPresent,
          );
        }),
        const SizedBox(height: 16),
        // Actions
        FilledButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Close'),
        ),
      ],
    );
  }
}

// ── Quote Medication Row ──
class _QuoteMedicationRow extends StatelessWidget {
  final int index;
  final PrescriptionItem item;
  final PharmacyProduct? product;
  final bool isPresent;

  const _QuoteMedicationRow({
    required this.index,
    required this.item,
    required this.product,
    required this.isPresent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPresent
            ? AppColors.error.withValues(alpha: 0.04)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPresent
              ? AppColors.error.withValues(alpha: 0.25)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Index badge
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isPresent
                  ? AppColors.error.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isPresent ? AppColors.error : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Medication name – red strikethrough if present
                Text.rich(
                  TextSpan(
                    text: item.medicationName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: isPresent
                          ? AppColors.error
                          : AppColors.textPrimary,
                      decoration: isPresent
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: AppColors.error,
                      decorationThickness: 2.0,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Details row
                Wrap(
                  spacing: 12,
                  children: [
                    _MiniChip(
                        icon: Icons.science_rounded,
                        text: item.dosage.isNotEmpty ? item.dosage : '-'),
                    _MiniChip(
                        icon: Icons.repeat_rounded,
                        text: item.frequency.isNotEmpty
                            ? item.frequency
                            : '-'),
                    _MiniChip(
                        icon: Icons.timer_rounded,
                        text: item.duration.isNotEmpty
                            ? item.duration
                            : '-'),
                    _MiniChip(
                        icon: Icons.numbers_rounded,
                        text: 'Qty ${item.quantity}'),
                  ],
                ),
                // Pharmacy price if found
                if (isPresent && product != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.local_pharmacy,
                          size: 14, color: AppColors.error),
                      const SizedBox(width: 6),
                      Text(
                        'In stock at ${product!.availableQty} units  •  KES ${product!.sellingPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (!isPresent) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 5),
                      Text('Not found in this pharmacy',
                          style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Status icon
          const SizedBox(width: 8),
          Icon(
            isPresent
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            color: isPresent ? AppColors.error : AppColors.textSecondary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(text,
            style: TextStyle(
                fontSize: 11.5, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text('$count',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: color)),
        Text(label,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style:
                TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
